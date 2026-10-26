import SwiftUI

/// The recitation player: a strip of green felt pinned with two brass brads.
///
/// Renders only when `AudioPlayerService.nowPlaying` is non-nil. Shows the qari,
/// the ayah being recited, a thin paper progress strip and transport controls.
struct PlayerBar: View {
    var service: AudioPlayerService = .shared
    /// Number of ayahs in the surah, for "Ayah 3 of 110". 0 hides the total.
    var totalAyahs: Int = 0

    private let ink = Color.lightCardSurface

    var body: some View {
        if let nowPlaying = service.nowPlaying {
            playerContent(nowPlaying: nowPlaying)
        }
    }

    // MARK: - Main content

    private func playerContent(nowPlaying: NowPlayingInfo) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                BrassBrad(size: 8)

                VStack(alignment: .leading, spacing: 1) {
                    Text(nowPlaying.qariName)
                        .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                    Text(subtitle(nowPlaying))
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(ink.opacity(0.78))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                transportControls(nowPlaying: nowPlaying)

                Button {
                    service.stop()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ink.opacity(0.75))
                        .frame(width: 36, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PaperPressStyle())
                .accessibilityLabel("Stop playback")
                .accessibilityIdentifier("playerCloseButton")

                BrassBrad(size: 8)
            }

            progressStrip
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .paperPiece(.lightPrimary, material: .felt, depth: 1.6, edge: .torn, radius: 10, seed: 73, padding: nil)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .transition(.offset(y: 24).combined(with: .opacity))
        .accessibilityIdentifier("playerBar")
        .accessibilityElement(children: .contain)
    }

    private func subtitle(_ nowPlaying: NowPlayingInfo) -> String {
        totalAyahs > 0
            ? "\(nowPlaying.surahName) · Ayah \(nowPlaying.ayahNumber) of \(totalAyahs)"
            : "\(nowPlaying.surahName) · Ayah \(nowPlaying.ayahNumber)"
    }

    /// A thin cream paper strip laid along the felt as the ayah plays.
    private var progressStrip: some View {
        GeometryReader { geo in
            let fraction = service.duration > 0 ? min(1, max(0, service.currentTime / service.duration)) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.18))
                Capsule()
                    .fill(Color.islamicGold)
                    .frame(width: max(3, geo.size.width * fraction))
                    .shadow(color: .black.opacity(0.25), radius: 0.5, y: 0.5)
            }
        }
        .frame(height: 3)
        .accessibilityElement()
        .accessibilityLabel("Playback progress")
        .accessibilityValue("\(Int((service.duration > 0 ? service.currentTime / service.duration : 0) * 100)) percent")
    }

    // MARK: - Transport controls

    @ViewBuilder
    private func transportControls(nowPlaying: NowPlayingInfo) -> some View {
        switch service.playerState {
        case .loading:
            ProgressView()
                .tint(ink)
                .scaleEffect(0.85)
                .frame(width: 44, height: 44)
                .accessibilityLabel("Loading audio")

        case .failed(let message):
            Button {
                Task { await service.retry() }
            } label: {
                Text("Retry")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.lightBodyText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .paperPiece(.islamicGold, material: .construction, depth: 0.6, edge: .torn, radius: 3, seed: 74, padding: nil)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PaperPressStyle())
            .accessibilityLabel("Retry audio playback. Playback error: \(message)")
            .accessibilityIdentifier("playerRetryButton")

        case .playing:
            playPauseButton(isPlaying: true)

        case .paused, .idle:
            playPauseButton(isPlaying: false)
        }
    }

    // MARK: - Play / Pause button

    private func playPauseButton(isPlaying: Bool) -> some View {
        Button {
            if isPlaying {
                service.pause()
            } else {
                service.resume()
            }
        } label: {
            PaperIconView(isPlaying ? .pause : .play, size: 24)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PaperPressStyle())
        .accessibilityLabel(isPlaying ? "Pause" : "Resume")
        .accessibilityIdentifier("playerPlayPauseButton")
    }
}
