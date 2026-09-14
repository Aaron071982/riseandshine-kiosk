import SwiftUI

extension Color {
    static let espresso = Color(hex: 0x2A2019)
    static let sunrise = Color(hex: 0xE7692C)
    static let sunriseDeep = Color(hex: 0xCF551A)
    static let sunriseTint = Color(hex: 0xFBE6D6)
    static let canvasBg = Color(hex: 0xFBF6F0)
    static let hairline = Color(hex: 0xEBE1D7)
    static let successGreen = Color(hex: 0x2E7D5B)
    static let mutedText = Color(hex: 0x93857A)

    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

enum RSFont {
    static let displayFamilyCandidates = [
        "Bricolage Grotesque",
        "BricolageGrotesque-96ptExtraBold",
        "Bricolage Grotesque 96pt ExtraBold",
    ]
    static let bodyFamilyCandidates = [
        "Inter Variable",
        "Inter",
        "Inter-Regular",
    ]

    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        custom(displayFamilyCandidates, size: size, weight: weight)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        custom(bodyFamilyCandidates, size: size, weight: weight)
    }

    private static func custom(_ names: [String], size: CGFloat, weight: Font.Weight) -> Font {
        for name in names {
            if UIFont(name: name, size: size) != nil {
                return Font.custom(name, size: size).weight(weight)
            }
        }
        return Font.system(size: size, weight: weight, design: .rounded)
    }
}
