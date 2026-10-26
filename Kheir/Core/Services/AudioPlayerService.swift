import Foundation
import AVFoundation
import SwiftUI
import MediaPlayer
import os

// MARK: - Supporting Types

/// Unified playback state consumed by all UI layers.
enum PlayerState: Equatable {
    case idle
    case loading
    case playing
    case paused
    case failed(String)

    static func == (lhs: PlayerState, rhs: PlayerState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.playing, .playing), (.paused, .paused):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

/// Metadata for the currently-playing ayah, used by the player bar UI and
/// MPNowPlayingInfoCenter.
struct NowPlayingInfo {
    let surahNumber: Int
    let ayahNumber: Int
    let surahName: String
    let qariName: String
}

// MARK: - AudioPlayerService

@MainActor
@Observable
final class AudioPlayerService {

    // MARK: Singleton
    static let shared = AudioPlayerService()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Kheir", category: "AudioPlayerService")

    // MARK: - Observed State

    /// Derived from `playerState`; kept as a plain var so existing SwiftUI
    /// `.animation(value:)` subscribers in ReadingView continue to fire via
    /// @Observable tracking.
    var isPlaying = false

    /// True while the item is buffering/loading; derived from `playerState`.
    var isLoading = false

    /// Zero-based index of the ayah currently playing within the loaded surah.
    var currentAyahIndex: Int = 0

    /// The identifier string of the active qari (e.g. "ar.alafasy").
    var selectedQari: String = AppSettings.shared.selectedQari

    /// Unified playback state. Drives `isPlaying` and `isLoading` as a side effect.
    var playerState: PlayerState = .idle {
        didSet { syncDerivedState() }
    }

    /// Elapsed playback position in seconds, updated every 0.5 s.
    var currentTime: TimeInterval = 0

    /// Total duration of the current item in seconds. Non-zero once item is ready.
    var duration: TimeInterval = 0

    /// Metadata for the track currently loaded into the player.
    var nowPlaying: NowPlayingInfo?

    // MARK: - Private State

    private var player: AVPlayer?

    /// Retained time observer token; must be removed before replacing the player.
    private var timeObserverToken: Any?

    /// KVO observation on the current AVPlayerItem's status.
    @ObservationIgnored private var itemStatusObservation: NSKeyValueObservation?

    /// Long-lived notification listeners (interruptions, route changes).
    @ObservationIgnored private var sessionNotificationTasks: [Task<Void, Never>] = []

    /// Listens for end-of-track on the current AVPlayerItem. Cancelled and
    /// replaced on each call to wireObservers(to:) so the old item's notification
    /// does not leak into the new item's lifecycle.
    @ObservationIgnored private var itemEndTask: Task<Void, Never>?

    /// Tracks whether the audio session has been fully configured at least once.
    private var sessionConfigured = false

    // MARK: - Legacy Private State (preserved for existing skip/configure logic)

    private var surahNumber: Int = 1
    private var totalAyahs: Int = 0

    // MARK: - Init

    private init() {
        configureSession()
        registerRemoteCommands()
        subscribeToInterruptions()
        subscribeToRouteChanges()
    }

    // MARK: - AVAudioSession Setup

    /// Configures the audio session for spoken Quran audio. Called once in init.
    private func configureSession() {
        guard !sessionConfigured else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers]
            )
            sessionConfigured = true
        } catch {
            logger.error("AVAudioSession category error: \(error.localizedDescription)")
        }
    }

    /// Activates the audio session immediately before playback begins.
    private func activateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logger.error("AVAudioSession activate error: \(error.localizedDescription)")
        }
    }

    /// Deactivates the audio session after the player has fully stopped, notifying
    /// other audio apps that they may resume.
    private func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        } catch {
            logger.error("AVAudioSession deactivate error: \(error.localizedDescription)")
        }
    }

    // MARK: - Interruption & Route-Change Handling

    // AVAudioSession posts these notifications on arbitrary threads. Each
    // listener iterates `NotificationCenter.notifications(named:)` inside a
    // main-actor Task, extracting only Sendable payload values, so state is
    // always mutated on the main actor.

    private func subscribeToInterruptions() {
        let notifications = NotificationCenter.default
            .notifications(named: AVAudioSession.interruptionNotification)
            .map { notification -> (type: UInt?, options: UInt) in
                let info = notification.userInfo
                return (
                    info?[AVAudioSessionInterruptionTypeKey] as? UInt,
                    info?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                )
            }
        sessionNotificationTasks.append(Task { [weak self] in
            for await payload in notifications {
                guard let self,
                      let typeValue = payload.type,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue)
                else { continue }

                switch type {
                case .began:
                    // Another app has taken audio focus — pause silently.
                    self.player?.pause()
                    self.playerState = .paused
                    self.isPlaying = false

                case .ended:
                    let options = AVAudioSession.InterruptionOptions(rawValue: payload.options)
                    if options.contains(.shouldResume) {
                        self.player?.play()
                        self.playerState = .playing
                    }

                @unknown default:
                    break
                }
            }
        })
    }

    private func subscribeToRouteChanges() {
        let reasons = NotificationCenter.default
            .notifications(named: AVAudioSession.routeChangeNotification)
            .map { $0.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt }
        sessionNotificationTasks.append(Task { [weak self] in
            for await reasonValue in reasons {
                guard let self,
                      let reasonValue,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
                      reason == .oldDeviceUnavailable
                else { continue }

                // Headphones unplugged — pause per Apple HIG.
                self.player?.pause()
                self.playerState = .paused
                self.isPlaying = false
            }
        })
    }

    // MARK: - MPRemoteCommandCenter

    private func registerRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .noActionableNowPlayingItem }
            self.resume()
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .noActionableNowPlayingItem }
            self.pause()
            return .success
        }

        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .noActionableNowPlayingItem }
            if self.isPlaying {
                self.pause()
            } else {
                self.resume()
            }
            return .success
        }

        // TODO (Phase 2b): wire skipForwardCommand and skipBackwardCommand for
        // skip-by-ayah from the lock screen.
    }

    // MARK: - MPNowPlayingInfoCenter

    private func updateNowPlayingInfo() {
        guard let info = nowPlaying else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var dict: [String: Any] = [
            MPMediaItemPropertyTitle: "\(info.surahName) — Ayah \(info.ayahNumber)",
            MPMediaItemPropertyArtist: info.qariName,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime
        ]

        if duration > 0 {
            dict[MPMediaItemPropertyPlaybackDuration] = duration
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = dict
    }

    // MARK: - Derived State Sync

    /// Keeps the legacy `isPlaying` / `isLoading` booleans in step with
    /// `playerState` so existing ReadingView animations and conditionals
    /// continue to work without modification.
    private func syncDerivedState() {
        switch playerState {
        case .playing:
            isPlaying = true
            isLoading = false
        case .loading:
            isPlaying = false
            isLoading = true
        case .paused, .idle, .failed:
            isPlaying = false
            isLoading = false
        }
    }

    // MARK: - Item Wiring Helpers

    /// Attaches the status KVO observer and end-of-track listener to `item`.
    /// Cleans up any prior observers first.
    ///
    /// KVO change handlers may fire on any thread, so the handler only reads
    /// the Sendable status value and hops to the main actor to apply it.
    private func wireObservers(to item: AVPlayerItem) {
        // Remove stale time observer from the old player before we replace it.
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }

        // KVO on item status to capture duration once the item is ready.
        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { @Sendable [weak self] observedItem, _ in
            let status = observedItem.status
            Task { @MainActor [weak self] in
                self?.handleItemStatus(status, for: item)
            }
        }

        // End-of-track — cancelling and replacing itemEndTask on the next
        // wireObservers(to:) call prevents a stale item from triggering auto-advance.
        itemEndTask?.cancel()
        let ends = NotificationCenter.default
            .notifications(named: AVPlayerItem.didPlayToEndTimeNotification, object: item)
            .map { _ in () }
        itemEndTask = Task { [weak self] in
            for await _ in ends {
                self?.handleTrackEnd()
            }
        }
    }

    /// Applies an AVPlayerItem status change on the main actor. Ignores
    /// callbacks for items that are no longer current.
    private func handleItemStatus(_ status: AVPlayerItem.Status, for item: AVPlayerItem) {
        guard player?.currentItem === item else { return }
        switch status {
        case .readyToPlay:
            let secs = item.duration.seconds
            if secs.isFinite && secs > 0 {
                duration = secs
                updateNowPlayingInfo()
            }
        case .failed:
            let desc = item.error?.localizedDescription ?? "Unknown playback error"
            playerState = .failed(desc)
            updateNowPlayingInfo()
        default:
            break
        }
    }

    /// Adds the 0.5-second periodic time observer after `player` has been set.
    private func addTimeObserver() {
        guard let player else { return }
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            // Delivered on `.main`, so we are already on the main actor.
            MainActor.assumeIsolated {
                guard let self else { return }
                let secs = time.seconds
                if secs.isFinite {
                    self.currentTime = secs
                    // Keep elapsed time in the lock-screen widget current.
                    if var info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
                        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = secs
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                    }
                }
            }
        }
    }

    // MARK: - Track End

    /// Called when the current AVPlayerItem plays to its end.
    /// Mirrors the legacy `playerDidFinish` auto-advance behaviour.
    private func handleTrackEnd() {
        if currentAyahIndex < totalAyahs - 1 {
            currentAyahIndex += 1
            play(surah: surahNumber, ayah: currentAyahIndex + 1)
        } else {
            playerState = .idle
            nowPlaying = nil
            player?.seek(to: .zero)
            currentTime = 0
            updateNowPlayingInfo()
        }
    }

    // MARK: - Configuration (legacy, preserved)

    /// Sets the surah context so skip-forward/backward know the total ayah count.
    func configure(surah: Int, totalAyahs: Int) {
        self.surahNumber = surah
        self.totalAyahs = totalAyahs
    }

    // MARK: - Core Playback (legacy sync API — preserved)

    /// Plays a specific ayah using the currently-selected qari identifier string.
    /// This is the legacy synchronous entry point. All existing call sites
    /// (ReadingViewModel.playFromAyah, skipForward, skipBackward, setQari,
    /// handleTrackEnd) continue to use this method unchanged.
    ///
    /// Populates `nowPlaying` and calls `updateNowPlayingInfo()` so that the
    /// `PlayerBar` and MPNowPlayingInfoCenter stay current during sequential
    /// (auto-advance) playback. The surah name defaults to "Surah N" because the
    /// legacy call site only carries the surah number; callers that have the
    /// real name should use `play(surahNumber:ayahNumber:surahName:qari:)` instead.
    func play(surah: Int, ayah: Int) {
        let resolved = Qari.resolve(selectedQari)
        guard let url = APIService.shared.audioURL(
            qari: resolved.identifier,
            surah: surah,
            ayah: ayah,
            bitrate: resolved.bitrate
        ) else {
            playerState = .failed("Could not build audio URL for \(surah):\(ayah)")
            return
        }

        // Tear down the previous player cleanly.
        tearDownPlayer()

        activateSession()
        playerState = .loading
        surahNumber = surah
        currentAyahIndex = ayah - 1

        // Preserve the existing surah name when auto-advancing within the same
        // surah; fall back to "Surah N" if nowPlaying is nil or belongs to a
        // different surah (e.g. after a setQari restart).
        let resolvedSurahName: String = {
            if let existing = nowPlaying, existing.surahNumber == surah {
                return existing.surahName
            }
            return "Surah \(surah)"
        }()

        nowPlaying = NowPlayingInfo(
            surahNumber: surah,
            ayahNumber: ayah,
            surahName: resolvedSurahName,
            qariName: resolved.name
        )

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)

        wireObservers(to: item)
        addTimeObserver()

        player?.play()
        playerState = .playing
        updateNowPlayingInfo()
    }

    // MARK: - New Primary Play Method (Phase 2a)

    /// Async entry point that accepts a full `Qari` value and populates
    /// `nowPlaying` + MPNowPlayingInfoCenter. Use this from any new UI that
    /// has access to the `Qari` model (e.g. a future dedicated player screen).
    func play(
        surahNumber: Int,
        ayahNumber: Int,
        surahName: String,
        qari: Qari
    ) async {
        guard let url = APIService.shared.audioURL(
            qari: qari.identifier,
            surah: surahNumber,
            ayah: ayahNumber,
            bitrate: qari.bitrate
        ) else {
            playerState = .failed("Could not build audio URL for \(surahNumber):\(ayahNumber)")
            return
        }

        tearDownPlayer()
        activateSession()

        playerState = .loading

        let info = NowPlayingInfo(
            surahNumber: surahNumber,
            ayahNumber: ayahNumber,
            surahName: surahName,
            qariName: qari.name
        )
        nowPlaying = info

        // Keep internal legacy state in sync so skip/configure logic works.
        self.surahNumber = surahNumber
        currentAyahIndex = ayahNumber - 1

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)

        wireObservers(to: item)
        addTimeObserver()

        player?.play()
        playerState = .playing
        updateNowPlayingInfo()
    }

    // MARK: - Pause / Resume / Stop (legacy, preserved)

    func pause() {
        player?.pause()
        playerState = .paused
        updateNowPlayingInfo()
    }

    func resume() {
        guard player != nil else { return }
        activateSession()
        player?.play()
        playerState = .playing
        updateNowPlayingInfo()
    }

    func stop() {
        tearDownPlayer()
        playerState = .idle
        nowPlaying = nil
        currentTime = 0
        duration = 0
        updateNowPlayingInfo()
        deactivateSession()
    }

    // MARK: - Skip Controls (legacy, preserved)

    func skipForward() {
        guard currentAyahIndex < totalAyahs - 1 else { return }
        currentAyahIndex += 1
        play(surah: surahNumber, ayah: currentAyahIndex + 1)
    }

    func skipBackward() {
        guard currentAyahIndex > 0 else { return }
        currentAyahIndex -= 1
        play(surah: surahNumber, ayah: currentAyahIndex + 1)
    }

    // MARK: - Qari Selection (legacy, preserved)

    func setQari(_ qari: String) {
        selectedQari = qari
        AppSettings.shared.selectedQari = qari
        if isPlaying {
            play(surah: surahNumber, ayah: currentAyahIndex + 1)
        }
    }

    // MARK: - Retry (Phase 2a)

    /// Re-attempts playback when `playerState` is `.failed` and `nowPlaying`
    /// metadata is available. No-op otherwise.
    func retry() async {
        guard case .failed = playerState, let info = nowPlaying else { return }
        // Reconstruct a minimal Qari from the stored identifier.
        let qari = Qari(identifier: selectedQari, name: info.qariName)
        await play(
            surahNumber: info.surahNumber,
            ayahNumber: info.ayahNumber,
            surahName: info.surahName,
            qari: qari
        )
    }

    // MARK: - Private Teardown

    /// Stops the player, removes all observers, and cancels item-scoped
    /// subscriptions so nothing leaks across item replacements.
    private func tearDownPlayer() {
        // Remove the periodic time observer before releasing the player.
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }

        itemStatusObservation?.invalidate()
        itemStatusObservation = nil

        // Cancel the per-item end-of-track listener. Interruption/route-change
        // listeners in `sessionNotificationTasks` are intentionally left alive.
        itemEndTask?.cancel()
        itemEndTask = nil

        player?.pause()
        player = nil
    }
}
