import Foundation
import CoreText

enum FontRegistration {
    static func registerBundledFonts() {
        let fileNames = ["Inter", "BricolageGrotesque"]
        let subdirs = [nil, "Fonts", "Resources/Fonts", "Resources"]
        for name in fileNames {
            var url: URL?
            for sub in subdirs {
                url = Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: sub)
                if url != nil { break }
            }
            guard let url else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
