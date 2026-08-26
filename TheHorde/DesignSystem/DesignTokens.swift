import SwiftUI

#if os(macOS)
import AppKit
#endif

enum DesignTokens {
    #if os(macOS)
    static let background = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 18 / 255, green: 18 / 255, blue: 26 / 255, alpha: 1)
            : NSColor(red: 244 / 255, green: 241 / 255, blue: 235 / 255, alpha: 1)
    })
    static let ink = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 244 / 255, green: 241 / 255, blue: 235 / 255, alpha: 1)
            : NSColor(red: 25 / 255, green: 23 / 255, blue: 34 / 255, alpha: 1)
    })
    #else
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 18 / 255, green: 18 / 255, blue: 26 / 255, alpha: 1)
            : UIColor(red: 244 / 255, green: 241 / 255, blue: 235 / 255, alpha: 1)
    })
    static let ink = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 244 / 255, green: 241 / 255, blue: 235 / 255, alpha: 1)
            : UIColor(red: 25 / 255, green: 23 / 255, blue: 34 / 255, alpha: 1)
    })
    #endif
    static let ember = Color(red: 215 / 255, green: 100 / 255, blue: 61 / 255)
    static let positive = Color(red: 44 / 255, green: 138 / 255, blue: 104 / 255)
    static let negative = Color(red: 184 / 255, green: 92 / 255, blue: 75 / 255)
    static let dungeon = Color(red: 23 / 255, green: 24 / 255, blue: 43 / 255)
    static let radius: CGFloat = 20
    static let margin: CGFloat = 16
    static let desktopMargin: CGFloat = 24
    static let desktopSpacing: CGFloat = 20
    static let readableWidth: CGFloat = 960
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: DesignTokens.radius))
    }
}

extension View {
    func hordeCard() -> some View { modifier(CardStyle()) }

    func hordeReadableContent(maxWidth: CGFloat = DesignTokens.readableWidth) -> some View {
        frame(maxWidth: maxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
