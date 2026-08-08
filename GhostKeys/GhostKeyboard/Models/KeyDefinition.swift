import UIKit

enum KeyType {
    case letter
    case shift
    case backspace
    case space
    case returnKey
    case switchMode
    case nextKeyboard
    case special
}

struct KeyDefinition {
    let primary: String
    let shifted: String
    let holdCharacters: [String]
    let widthMultiplier: CGFloat
    let type: KeyType

    static func letter(_ p: String, shifted: String? = nil, hold: [String] = []) -> KeyDefinition {
        KeyDefinition(primary: p, shifted: shifted ?? p.uppercased(), holdCharacters: hold, widthMultiplier: 1.0, type: .letter)
    }

    static let shift    = KeyDefinition(primary: "⇧", shifted: "⇧", holdCharacters: [], widthMultiplier: 1.35, type: .shift)
    static let backspace = KeyDefinition(primary: "⌫", shifted: "⌫", holdCharacters: [], widthMultiplier: 1.35, type: .backspace)
    static let space    = KeyDefinition(primary: "space", shifted: "space", holdCharacters: [], widthMultiplier: 4.5, type: .space)
    static let returnKey = KeyDefinition(primary: "return", shifted: "return", holdCharacters: [], widthMultiplier: 2.0, type: .returnKey)
    static let switch123 = KeyDefinition(primary: "123", shifted: "123", holdCharacters: [], widthMultiplier: 1.35, type: .switchMode)
    static let switchABC = KeyDefinition(primary: "ABC", shifted: "ABC", holdCharacters: [], widthMultiplier: 1.35, type: .switchMode)
    static let switchSym = KeyDefinition(primary: "#+=", shifted: "#+=", holdCharacters: [], widthMultiplier: 1.35, type: .switchMode)
    static let globe     = KeyDefinition(primary: "🌐", shifted: "🌐", holdCharacters: [], widthMultiplier: 1.0, type: .nextKeyboard)
}
