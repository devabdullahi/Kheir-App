import SwiftUI

/// A reusable verse row component for the Quran reading experience.
///
/// Renders a single ayah with full audio-sync highlighting support:
/// - Active state shows a gold left border, tinted background, and a live progress bar.
/// - Inactive state renders with reduced opacity and no background decoration.
/// - RTL layout is applied to the Arabic text via `.environment(\.layoutDirection, .rightToLeft)`.
///
/// Usage:
/// ```swift
/// VerseHighlightView(
///     verseNumber: ayah.numberInSurah,
///     arabicText: ayah.arabicText,
///     translation: ayah.translationText,
///     isActive: audioPlayer.currentAyahIndex == ayah.numberInSurah - 1,
///     audioProgress: audioPlayer.verseProgress,
///     colorScheme: colorScheme
/// ) {
///     Task { await audioPlayer.play(...) }
/// }
/// ```
struct VerseHighlightView: View {

    // MARK: - Parameters

    let verseNumber: Int
    let arabicText: String
    let translation: String
    let isActive: Bool
    let audioProgress: Double
    let colorScheme: ColorScheme
    let onTap: () -> Void

    // MARK: - Press state

    @State private var isPressed: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Design constants (Sacred Garden palette)

    private let gold = Color(red: 0.831, green: 0.659, blue: 0.278)         // #D4A847
    private let primaryGreen = Color(red: 0.133, green: 0.341, blue: 0.235) // #22573C
    private let primaryText = Color(red: 0.910, green: 0.863, blue: 0.784)  // #E8DCC8

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // Gold left border — visible only when active
            activeLeftBorder

            // Main content
            mainContent
        }
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(
            reduceMotion ? .none : .easeInOut(duration: 0.25),
            value: isActive
        )
        .animation(
            reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7),
            value: isPressed
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in
                    isPressed = false
                    onTap()
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Verse \(verseNumber). \(translation)")
        .accessibilityHint("Double tap to play from this verse")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Left Border

    @ViewBuilder
    private var activeLeftBorder: some View {
        if isActive {
            gold
                .frame(width: 3)
                .clipShape(
                    // Flat on the left (leading), rounded on the right side — the
                    // 3-pt strip is too narrow for visible corner rounding, but we
                    // mirror the container's geometry exactly.
                    RoundedRectangle(cornerRadius: 0)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .leading)))
        }
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Arabic text with inline verse-number circle
            arabicRow

            // Translation
            translationText

            // Audio progress bar (active only)
            if isActive {
                audioProgressBar
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, isActive ? 16 : 0)
        .background(activeBackground)
        .clipShape(activeClipShape)
    }

    // MARK: - Arabic row

    private var arabicRow: some View {
        HStack(alignment: .center, spacing: 8) {
            // Verse number circle — sits at the trailing end of the Arabic line.
            // We keep it in leading position inside the HStack but rely on the
            // RTL environment on the Text to push the Arabic to the right.
            verseNumberCircle

            Spacer(minLength: 0)

            Text(arabicText)
                .font(.custom("ScheherazadeNew-Regular", size: 24))
                .environment(\.layoutDirection, .rightToLeft)
                .multilineTextAlignment(.trailing)
                .lineSpacing(24)
                .foregroundStyle(primaryText.opacity(isActive ? 1.0 : 0.75))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Verse number circle

    private var verseNumberCircle: some View {
        ZStack {
            Circle()
                .stroke(gold.opacity(0.15), lineWidth: 1)
                .frame(width: 24, height: 24)

            Text("\(verseNumber)")
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(gold.opacity(isActive ? 1.0 : 0.5))
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }

    // MARK: - Translation

    private var translationText: some View {
        Text(translation)
            .font(.system(size: 13))
            .foregroundStyle(primaryText.opacity(isActive ? 0.6 : 0.4))
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineSpacing(translationLineSpacing)
            // Dynamic Type for translation — Arabic stays at fixed 24pt.
            .dynamicTypeSize(.small ... .accessibility3)
    }

    /// Approximates 1.6× line height for 13pt text.
    /// SwiftUI's `.lineSpacing` adds extra space between lines (not a multiplier),
    /// so we subtract the font's own leading: 13 × 1.6 − 13 ≈ 7.8 → 8pt extra.
    private var translationLineSpacing: CGFloat { 8 }

    // MARK: - Audio progress bar

    private var audioProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(primaryGreen.opacity(0.3))
                    .frame(height: 2)

                // Fill
                Capsule()
                    .fill(gold)
                    .frame(width: geo.size.width * max(0, min(1, audioProgress)), height: 2)
                    .animation(
                        reduceMotion ? .none : .linear(duration: 0.1),
                        value: audioProgress
                    )
            }
        }
        .frame(height: 2)
        .accessibilityHidden(true)
    }

    // MARK: - Background helpers

    @ViewBuilder
    private var activeBackground: some View {
        if isActive {
            primaryGreen.opacity(0.15)
        }
    }

    /// Flat left edge when active (sits flush against the gold border strip),
    /// 12pt radius on the right corners.
    private var activeClipShape: some Shape {
        isActive ? AnyShape(ActiveVerseShape()) : AnyShape(Rectangle())
    }
}

// MARK: - Active verse shape
// Left edge is flat (radius = 0), right corners are rounded to 12pt.
private struct ActiveVerseShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 12
        var path = Path()
        // Start top-left (flat)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        // Top edge → top-right corner (rounded)
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        // Right edge → bottom-right corner (rounded)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        // Bottom edge → bottom-left (flat)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - AnyShape (iOS 17 backport for conditional shape erasure)
private struct AnyShape: Shape {
    private let _path: (CGRect) -> Path
    init<S: Shape>(_ shape: S) { _path = shape.path(in:) }
    func path(in rect: CGRect) -> Path { _path(rect) }
}

// MARK: - Preview

#if DEBUG
#Preview("Active verse — dark") {
    VStack(spacing: 0) {
        VerseHighlightView(
            verseNumber: 1,
            arabicText: "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ",
            translation: "In the name of Allah, the Entirely Merciful, the Especially Merciful.",
            isActive: true,
            audioProgress: 0.6,
            colorScheme: .dark
        ) {}

        VerseHighlightView(
            verseNumber: 2,
            arabicText: "ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ",
            translation: "All praise is due to Allah, Lord of the worlds —",
            isActive: false,
            audioProgress: 0,
            colorScheme: .dark
        ) {}

        VerseHighlightView(
            verseNumber: 3,
            arabicText: "ٱلرَّحْمَٰنِ ٱلرَّحِيمِ",
            translation: "The Entirely Merciful, the Especially Merciful,",
            isActive: false,
            audioProgress: 0,
            colorScheme: .dark
        ) {}
    }
    .padding(.horizontal, 16)
    .background(Color(red: 0.039, green: 0.059, blue: 0.118))
    .preferredColorScheme(.dark)
}

#Preview("Active verse — light") {
    VStack(spacing: 0) {
        VerseHighlightView(
            verseNumber: 1,
            arabicText: "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ",
            translation: "In the name of Allah, the Entirely Merciful, the Especially Merciful.",
            isActive: true,
            audioProgress: 0.35,
            colorScheme: .light
        ) {}

        VerseHighlightView(
            verseNumber: 2,
            arabicText: "ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ",
            translation: "All praise is due to Allah, Lord of the worlds —",
            isActive: false,
            audioProgress: 0,
            colorScheme: .light
        ) {}
    }
    .padding(.horizontal, 16)
    .background(Color(red: 0.961, green: 0.941, blue: 0.910))
    .preferredColorScheme(.light)
}

#Preview("Progress bar states") {
    VStack(spacing: 0) {
        ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { progress in
            VerseHighlightView(
                verseNumber: 1,
                arabicText: "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ",
                translation: "Progress: \(Int(progress * 100))%",
                isActive: true,
                audioProgress: progress,
                colorScheme: .dark
            ) {}
        }
    }
    .padding(.horizontal, 16)
    .background(Color(red: 0.039, green: 0.059, blue: 0.118))
    .preferredColorScheme(.dark)
}
#endif
