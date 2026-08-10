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
    let popupHighlight: UIColor
    let accentBlue: UIColor
}

enum ThemeManager {
    static func theme(for style: UIUserInterfaceStyle) -> KeyboardTheme {
        if style == .dark {
            return KeyboardTheme(
                keyBackground: UIColor(red: 0.42, green: 0.42, blue: 0.44, alpha: 1.0),
                specialKeyBackground: UIColor(red: 0.29, green: 0.29, blue: 0.30, alpha: 1.0),
                keyTextColor: .white,
                keyHighlightColor: UIColor(red: 0.60, green: 0.60, blue: 0.62, alpha: 1.0),
                suggestionBarBackground: .clear,
                keyboardBackground: .clear,
                keyShadowColor: UIColor.black.withAlphaComponent(0.4),
                popupBackground: UIColor(red: 0.25, green: 0.25, blue: 0.26, alpha: 1.0),
                popupHighlight: UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0),
                accentBlue: UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
            )
        } else {
            return KeyboardTheme(
                keyBackground: .white,
                specialKeyBackground: UIColor(red: 0.67, green: 0.70, blue: 0.75, alpha: 1.0),
                keyTextColor: .black,
                keyHighlightColor: UIColor(red: 0.83, green: 0.85, blue: 0.88, alpha: 1.0),
                suggestionBarBackground: .clear,
                keyboardBackground: .clear,
                keyShadowColor: UIColor.black.withAlphaComponent(0.25),
                popupBackground: .white,
                popupHighlight: UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0),
                accentBlue: UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
            )
        }
    }
}
