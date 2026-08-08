import Foundation

enum KeyboardLayout {
    // Letters layout — Gboard-style long-press mapping (numbers on top row, symbols/accents on lower rows).
    static let letters: [[KeyDefinition]] = [
        [
            .letter("q", hold: ["1"]),
            .letter("w", hold: ["2"]),
            .letter("e", hold: ["3", "è", "é", "ê", "ë", "ē"]),
            .letter("r", hold: ["4"]),
            .letter("t", hold: ["5", "þ"]),
            .letter("y", hold: ["6", "ý", "ÿ"]),
            .letter("u", hold: ["7", "ù", "ú", "û", "ü", "ū"]),
            .letter("i", hold: ["8", "ì", "í", "î", "ï", "ī"]),
            .letter("o", hold: ["9", "ò", "ó", "ô", "ö", "ø", "ō"]),
            .letter("p", hold: ["0"])
        ],
        [
            .letter("a", hold: ["@", "à", "á", "â", "ä", "æ", "ā"]),
            .letter("s", hold: ["#", "ß", "ś", "š"]),
            .letter("d", hold: ["$"]),
            .letter("f", hold: ["%"]),
            .letter("g", hold: ["&"]),
            .letter("h", hold: ["-", "–", "—"]),
            .letter("j", hold: ["+"]),
            .letter("k", hold: ["("]),
            .letter("l", hold: [")"])
        ],
        [
            .shift,
            .letter("z", hold: ["*", "ž", "ź"]),
            .letter("x", hold: ["\""]),
            .letter("c", hold: ["'", "ç", "ć", "č"]),
            .letter("v", hold: [":"]),
            .letter("b", hold: [";"]),
            .letter("n", hold: ["!", "ñ", "ń"]),
            .letter("m", hold: ["?", "—"]),
            .backspace
        ],
        [
            .switch123,
            .globe,
            .space,
            .returnKey
        ]
    ]

    static let symbols1: [[KeyDefinition]] = [
        [
            .letter("1"), .letter("2"), .letter("3"), .letter("4"), .letter("5"),
            .letter("6"), .letter("7"), .letter("8"), .letter("9"), .letter("0")
        ],
        [
            .letter("-"), .letter("/"), .letter(":"), .letter(";"), .letter("("),
            .letter(")"), .letter("$"), .letter("&"), .letter("@"), .letter("\"")
        ],
        [
            .switchSym,
            .letter("."), .letter(","), .letter("?"), .letter("!"), .letter("'"),
            .backspace
        ],
        [
            .switchABC,
            .globe,
            .space,
            .returnKey
        ]
    ]

    static let symbols2: [[KeyDefinition]] = [
        [
            .letter("["), .letter("]"), .letter("{"), .letter("}"), .letter("#"),
            .letter("%"), .letter("^"), .letter("*"), .letter("+"), .letter("=")
        ],
        [
            .letter("_"), .letter("\\"), .letter("|"), .letter("~"), .letter("<"),
            .letter(">"), .letter("€"), .letter("£"), .letter("¥"), .letter("·")
        ],
        [
            .switch123,
            .letter("."), .letter(","), .letter("?"), .letter("!"), .letter("'"),
            .backspace
        ],
        [
            .switchABC,
            .globe,
            .space,
            .returnKey
        ]
    ]

    static func rows(for page: KeyboardPage) -> [[KeyDefinition]] {
        switch page {
        case .letters:  return letters
        case .symbols1: return symbols1
        case .symbols2: return symbols2
        }
    }
}
