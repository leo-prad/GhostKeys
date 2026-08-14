import UIKit

struct KeyboardTheme {
    let keyBackground: UIColor
    let specialKeyBackground: UIColor
    let keyTextColor: UIColor
    let keyHighlightColor: UIColor
    let suggestionBarBackground: UIColor
    let keyboardBackground: UIColor
    let keyShadowColor: UIColor
    let popupBackground: UIColor
    let keyPreviewBackground: UIColor
    let keyPreviewBorder: UIColor
    let popupHighlight: UIColor
    let accentBlue: UIColor
}

enum ThemeManager {
    static func theme(for style: UIUserInterfaceStyle) -> KeyboardTheme {
        if style == .dark {
            return KeyboardTheme(
                keyBackground: UIColor(red: 106.0 / 255.0, green: 106.0 / 255.0, blue: 106.0 / 255.0, alpha: 1.0),
                specialKeyBackground: UIColor(red: 106.0 / 255.0, green: 106.0 / 255.0, blue: 106.0 / 255.0, alpha: 1.0),
                keyTextColor: .white,
                keyHighlightColor: UIColor(red: 0.60, green: 0.60, blue: 0.62, alpha: 1.0),
                suggestionBarBackground: .clear,
                keyboardBackground: .clear,
                keyShadowColor: UIColor.black.withAlphaComponent(0.4),
                popupBackground: UIColor(red: 45.0 / 255.0, green: 45.0 / 255.0, blue: 45.0 / 255.0, alpha: 1.0),
                keyPreviewBackground: UIColor(red: 45.0 / 255.0, green: 45.0 / 255.0, blue: 45.0 / 255.0, alpha: 1.0),
                keyPreviewBorder: UIColor(red: 0.38, green: 0.38, blue: 0.39, alpha: 1.0),
                popupHighlight: UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0),
                accentBlue: UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
            )
        } else {
            return KeyboardTheme(
                keyBackground: .white,
                specialKeyBackground: .white,
                keyTextColor: .black,
                keyHighlightColor: UIColor(red: 0.83, green: 0.85, blue: 0.88, alpha: 1.0),
                suggestionBarBackground: .clear,
                keyboardBackground: .clear,
                keyShadowColor: UIColor.black.withAlphaComponent(0.25),
                popupBackground: .white,
                keyPreviewBackground: .white,
                keyPreviewBorder: UIColor.black.withAlphaComponent(0.18),
                popupHighlight: UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0),
                accentBlue: UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
            )
        }
    }
}
