import SwiftUI

// MARK: - Sacred Garden Template Container

/// Enumerates the three premium Sacred Garden share card templates.
/// Use `view(reference:arabicText:translation:contentType:)` to instantiate the
/// appropriate SwiftUI view for image export.
enum SacredGardenTemplate: CaseIterable {
    case sacredNight
    case sereneGarden
    case maghribGlow

    // MARK: Display Metadata

    var displayName: String {
        switch self {
        case .sacredNight:   return "Sacred Night"
        case .sereneGarden:  return "Serene Garden"
        case .maghribGlow:   return "Maghrib Glow"
        }
    }

    // MARK: View Factory

    /// Returns the concrete card view ready for rendering or image export.
    @ViewBuilder
    func view(
        reference: String,
        arabicText: String,
        translation: String,
        contentType: ShareContentType
    ) -> some View {
        switch self {
        case .sacredNight:
            SacredNightCard(
                reference: reference,
                arabicText: arabicText,
                translation: translation,
                contentType: contentType
            )
        case .sereneGarden:
            SereneGardenCard(
                reference: reference,
                arabicText: arabicText,
                translation: translation,
                contentType: contentType
            )
        case .maghribGlow:
            MaghribGlowCard(
                reference: reference,
                arabicText: arabicText,
                translation: translation,
                contentType: contentType
            )
        }
    }
}

// MARK: - Shared Private Helpers

/// A horizontal gradient divider used by SacredNightCard and MaghribGlowCard.
private struct FadeLineDivider: View {
    let color: Color
    let height: CGFloat

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: color.opacity(0.3), location: 0.3),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: height)
    }
}

/// A pill-shaped divider with solid colour used by SereneGardenCard.
private struct SolidLineDivider: View {
    let color: Color
    let height: CGFloat

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: color, location: 0),
                .init(color: color, location: 0.1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: height)
        .clipShape(Capsule())
    }
}

// MARK: - Card Size Constants

private enum CardLayout {
    static let width:         CGFloat = 340
    static let height:        CGFloat = 440
    static let cornerRadius:  CGFloat = 16
    static let padding:       CGFloat = 24
}

// MARK: - Template 1: SacredNightCard

/// Deep navy-to-emerald gradient card with gold accents. Ideal for dark-mode
/// social sharing.  Fixed at 340 × 440 pt.
struct SacredNightCard: View {

    // MARK: Inputs
    let reference:   String
    let arabicText:  String
    let translation: String
    let contentType: ShareContentType

    // MARK: Design Tokens
    private let backgroundColors: [Color] = [
        Color(red: 0.039, green: 0.059, blue: 0.118),
        Color(red: 0.051, green: 0.122, blue: 0.102)
    ]
    private let gold     = Color(red: 0.831, green: 0.659, blue: 0.278)
    private let cream    = Color(red: 0.910, green: 0.863, blue: 0.784)

    // MARK: Body

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: backgroundColors,
                startPoint: UnitPoint(x: cos(145 * .pi / 180) * 0.5 + 0.5,
                                     y: sin(145 * .pi / 180) * 0.5 + 0.5),
                endPoint:   UnitPoint(x: cos((145 + 180) * .pi / 180) * 0.5 + 0.5,
                                     y: sin((145 + 180) * .pi / 180) * 0.5 + 0.5)
            )

            // Content stack
            VStack(alignment: .leading, spacing: 0) {

                // Overline — reference
                Text(reference.uppercased())
                    .font(.system(size: 9, weight: .regular))
                    .tracking(2)
                    .foregroundStyle(gold.opacity(0.60))
                    .padding(.bottom, 12)

                // Arabic text
                Text(arabicText)
                    .font(.custom("ScheherazadeNew-Regular", size: 20))
                    .environment(\.layoutDirection, .rightToLeft)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(cream)
                    .lineSpacing(20 * (1.9 - 1))   // line-height 1.9 × font size
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.bottom, 16)

                // Gradient divider
                FadeLineDivider(color: gold, height: 1)
                    .padding(.bottom, 14)

                // Translation
                Text(translation)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(cream.opacity(0.50))
                    .lineSpacing(11 * (1.5 - 1))   // line-height 1.5 × font size
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // Footer
                HStack(spacing: 0) {
                    Text("KHEIR")
                        .font(.system(size: 8, weight: .regular))
                        .tracking(1)
                        .foregroundStyle(gold.opacity(0.40))

                    Spacer()

                    Image(systemName: "moon.stars")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(cream.opacity(0.30))
                }
            }
            .padding(CardLayout.padding)
        }
        .frame(width: CardLayout.width, height: CardLayout.height)
        .clipShape(RoundedRectangle(cornerRadius: CardLayout.cornerRadius, style: .continuous))
        .drawingGroup()
    }
}

// MARK: - Template 2: SereneGardenCard

/// Warm parchment gradient card with forest-green and muted-gold accents. Suited
/// to light-mode aesthetics and print-adjacent outputs.  Fixed at 340 × 440 pt.
struct SereneGardenCard: View {

    // MARK: Inputs
    let reference:   String
    let arabicText:  String
    let translation: String
    let contentType: ShareContentType

    // MARK: Design Tokens
    private let backgroundColors: [Color] = [
        Color(red: 0.961, green: 0.941, blue: 0.910),
        Color(red: 0.929, green: 0.906, blue: 0.855)
    ]
    private let green           = Color(red: 0.133, green: 0.341, blue: 0.235)
    private let darkText        = Color(red: 0.102, green: 0.165, blue: 0.133)
    private let secondaryText   = Color(red: 0.353, green: 0.420, blue: 0.384)
    private let footerGold      = Color(red: 0.722, green: 0.573, blue: 0.180)

    // MARK: Body

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: backgroundColors,
                startPoint: UnitPoint(x: cos(160 * .pi / 180) * 0.5 + 0.5,
                                     y: sin(160 * .pi / 180) * 0.5 + 0.5),
                endPoint:   UnitPoint(x: cos((160 + 180) * .pi / 180) * 0.5 + 0.5,
                                     y: sin((160 + 180) * .pi / 180) * 0.5 + 0.5)
            )

            // Content stack
            VStack(alignment: .leading, spacing: 0) {

                // Overline — reference
                Text(reference.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(green)
                    .padding(.bottom, 12)

                // Arabic text
                Text(arabicText)
                    .font(.custom("ScheherazadeNew-Regular", size: 20))
                    .environment(\.layoutDirection, .rightToLeft)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(darkText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.bottom, 16)

                // Solid 2 px pill divider
                SolidLineDivider(color: green, height: 2)
                    .padding(.bottom, 14)

                // Translation
                Text(translation)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(secondaryText)
                    .lineSpacing(11 * (1.5 - 1))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // Footer
                HStack(spacing: 0) {
                    Text("KHEIR")
                        .font(.system(size: 8, weight: .regular))
                        .tracking(1)
                        .foregroundStyle(footerGold)

                    Spacer()

                    Image(systemName: "moon.stars")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(green.opacity(0.20))
                }
            }
            .padding(CardLayout.padding)
        }
        .frame(width: CardLayout.width, height: CardLayout.height)
        .clipShape(RoundedRectangle(cornerRadius: CardLayout.cornerRadius, style: .continuous))
        .drawingGroup()
    }
}

// MARK: - Template 3: MaghribGlowCard

/// Four-stop sunset gradient (deep violet → magenta → burnt orange → warm amber).
/// Evokes the Maghrib sky.  Fixed at 340 × 440 pt.
struct MaghribGlowCard: View {

    // MARK: Inputs
    let reference:   String
    let arabicText:  String
    let translation: String
    let contentType: ShareContentType

    // MARK: Design Tokens
    private let backgroundColors: [Color] = [
        Color(red: 0.165, green: 0.102, blue: 0.227),  // deep violet
        Color(red: 0.545, green: 0.180, blue: 0.290),  // magenta rose
        Color(red: 0.831, green: 0.412, blue: 0.290),  // burnt orange
        Color(red: 0.910, green: 0.659, blue: 0.478)   // warm amber
    ]
    private let cream       = Color(red: 0.941, green: 0.784, blue: 0.541)
    private let arabicWhite = Color(red: 1.0,   green: 0.961, blue: 0.878)  // #FFF5E0

    // MARK: Body

    var body: some View {
        ZStack {
            // Background — pure 180° vertical gradient
            LinearGradient(
                colors: backgroundColors,
                startPoint: .top,
                endPoint:   .bottom
            )

            // Content stack
            VStack(alignment: .leading, spacing: 0) {

                // Overline — reference
                Text(reference.uppercased())
                    .font(.system(size: 9, weight: .regular))
                    .tracking(2)
                    .foregroundStyle(cream.opacity(0.70))
                    .padding(.bottom, 12)

                // Arabic text
                Text(arabicText)
                    .font(.custom("ScheherazadeNew-Regular", size: 20))
                    .environment(\.layoutDirection, .rightToLeft)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(arabicWhite)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.bottom, 16)

                // Gradient divider
                FadeLineDivider(color: cream, height: 1)
                    .padding(.bottom, 14)

                // Translation
                Text(translation)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(cream.opacity(0.60))
                    .lineSpacing(11 * (1.5 - 1))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // Footer
                HStack(spacing: 0) {
                    Text("KHEIR")
                        .font(.system(size: 8, weight: .regular))
                        .tracking(1)
                        .foregroundStyle(cream.opacity(0.50))

                    Spacer()

                    Image(systemName: "moon.stars")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(cream.opacity(0.30))
                }
            }
            .padding(CardLayout.padding)
        }
        .frame(width: CardLayout.width, height: CardLayout.height)
        .clipShape(RoundedRectangle(cornerRadius: CardLayout.cornerRadius, style: .continuous))
        .drawingGroup()
    }
}

// MARK: - Xcode Preview

#if DEBUG
#Preview("Sacred Garden Templates") {
    let sampleReference   = "Al-Fatiha 1:1"
    let sampleArabic      = "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ"
    let sampleTranslation = "In the name of Allah, the Entirely Merciful, the Especially Merciful."

    ScrollView {
        VStack(spacing: 32) {
            ForEach(SacredGardenTemplate.allCases, id: \.displayName) { template in
                VStack(spacing: 8) {
                    Text(template.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    template.view(
                        reference:   sampleReference,
                        arabicText:  sampleArabic,
                        translation: sampleTranslation,
                        contentType: .ayah
                    )
                }
            }
        }
        .padding()
    }
    .background(Color(red: 0.12, green: 0.12, blue: 0.14))
}
#endif
