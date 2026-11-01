import CoreText
import Foundation

/// The Arabic typefaces bundled with the app (both SIL Open Font License):
/// Scheherazade New for Arabic across the app, Amiri Quran for the mushaf.
enum AppFonts {
    /// Registers the bundled fonts once per launch.
    static let registered: Void = {
        for name in ["ScheherazadeNew-Regular", "AmiriQuran-Regular"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()
}
