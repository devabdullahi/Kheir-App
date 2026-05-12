import SwiftUI

/// A floating inline audio player bar that shows current ayah recitation status.
///
/// Renders only when `AudioPlayerService.nowPlaying` is non-nil. Displays the
/// surah name, ayah number, qari name, playback progress, and transport controls.
/// Entrance animation uses `.move(edge: .bottom).combined(with: .opacity)`.
struct PlayerBar: View {
    @ObservedObject var service: AudioPlayerService = .shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let nowPlaying = service.nowPlaying {
            playerContent(nowPlaying: nowPlaying)
        }
    }

    // MARK: - Main content

    private func playerContent(nowPlaying: NowPlayingInfo) -> some View {
        VStack(spacing: 6) {
            // Main row
            HStack(spacing: 12) {
                // Leading icon
                Image(systemName: "speaker.wave.2.fill")
                    .font(.body)
                    .foregroundStyle(Color.adaptivePrimary(colorScheme))
                    .accessibilityHidden(true)

                // Title / subtitle stack
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(nowPlaying.surahName) — Ayah \(nowPlaying.ayahNumber)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineLimit(1)

                    Text(nowPlaying.qariName)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                        .lineLimit(1)
                }

                Spacer()

                // Transport controls — state-dependent
                transportControls(nowPlaying: nowPlaying)

                // Close / stop button
                Button {
                    service.stop()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop playback")
                .accessibilityIdentifier("playerCloseButton")
            }

            // Progress bar row
            ProgressView(
                value: service.currentTime,
                total: max(service.duration, 0.001)
            )
            .progressViewStyle(.linear)
            .tint(Color.adaptivePrimary(colorScheme))
            .accessibilityLabel("Playback progress")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.adaptiveCardSurface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08),
            radius: 8,
            y: 4
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityIdentifier("playerBar")
        .accessibilityElement(children: .contain)
    }

    // MARK: - Transport controls

    @ViewBuilder
    private func transportControls(nowPlaying: NowPlayingInfo) -> some View {
        switch service.playerState {
        case .loading:
            ProgressView()
                .scaleEffect(0.85)
                .frame(width: 44, height: 44)
                .accessibilityLabel("Loading audio")

        case .failed(let message):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                    .accessibilityLabel("Playback error: \(message)")

                Button {
                    Task { await service.retry() }
                } label: {
                    Text("Retry")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Retry audio playback")
                .accessibilityIdentifier("playerRetryButton")
            }

        case .playing:
            playPauseButton(isPlaying: true, nowPlaying: nowPlaying)

        case .paused, .idle:
            playPauseButton(isPlaying: false, nowPlaying: nowPlaying)
        }
    }

    // MARK: - Play / Pause button

    private func playPauseButton(isPlaying: Bool, nowPlaying: NowPlayingInfo) -> some View {
        Button {
            if isPlaying {
                service.pause()
            } else {
                // Alpha's contract exposes resume(). The current AudioPlayerService.swift
                // already has a synchronous resume() at line 68 that calls player?.play().
                // Use that directly; no need to restart the stream.
                service.resume()
            }
        } label: {
            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.adaptivePrimary(colorScheme))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Pause" : "Resume")
        .accessibilityIdentifier("playerPlayPauseButton")
    }
}
