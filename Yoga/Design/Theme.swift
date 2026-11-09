import SwiftUI

/// "Kvällsvärme" (evening warmth): the studio's sage, olive and gold, moved
/// into a dusk palette that sits calmly in a dark living room.
enum Palette {
    static let ink = Color(hex: "#100F0B")!
    static let dusk = Color(hex: "#211E15")!
    static let ember = Color(hex: "#3A2E14")!
    static let cream = Color(hex: "#F3F1E7")!
    static let sand = Color(hex: "#C9BFA0")!
    static let olive = Color(hex: "#8B7F5E")!
    static let gold = Color(hex: "#E8B93A")!
    static let paleGold = Color(hex: "#F6D27A")!

    static let textPrimary = cream
    static let textSecondary = cream.opacity(0.62)
    static let textTertiary = cream.opacity(0.38)
    static let hairline = cream.opacity(0.10)
}

/// A strict type scale. Light display weights, with tracked small caps for labels.
enum Typeface {
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .ultraLight) }
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .light) }
    static func body(_ size: CGFloat = 27) -> Font { .system(size: size, weight: .regular) }
    static func label(_ size: CGFloat = 19) -> Font { .system(size: size, weight: .semibold) }
    static func numeral(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }
}

enum Motion {
    static let focus = Animation.spring(response: 0.32, dampingFraction: 0.78)
    static let reveal = Animation.spring(response: 0.9, dampingFraction: 0.9)
    /// One full breath: in, then out.
    static let breath = Animation.easeInOut(duration: 5.5).repeatForever(autoreverses: true)
}

extension View {
    /// Tracked, uppercase micro-label: the typographic voice of the app.
    func eyebrow(_ color: Color = Palette.textSecondary, size: CGFloat = 19, tracking: CGFloat = 4.5) -> some View {
        self.font(Typeface.label(size))
            .textCase(.uppercase)
            .tracking(tracking)
            .foregroundStyle(color)
    }
}
