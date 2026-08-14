import Foundation

enum KeyboardLayout {
    // Letters layout — Gboard-style long-press mapping (numbers on top row, symbols/accents on lower rows).
    static let letters: [[KeyDefinition]] = [
        [
            .letter("q", hold: ["1"]),
            .letter("w", hold: ["2", "ŵ"]),
            .letter("e", hold: ["3", "è", "é", "ê", "ë", "ē", "ė", "ę"]),
            .letter("r", hold: ["4", "ř", "ŕ", "ṙ"]),
            .letter("t", hold: ["5", "þ", "ť", "ţ"]),
            .letter("y", hold: ["6", "ÿ", "ý", "ŷ"]),
            .letter("u", hold: ["7", "ù", "ú", "û", "ü", "ū", "ų", "ű"]),
            .letter("i", hold: ["8", "ì", "í", "î", "ï", "ī", "į", "ı"]),
            .letter("o", hold: ["9", "ò", "ó", "ô", "ö", "ø", "õ", "œ", "ō"]),
            .letter("p", hold: ["0", "ṗ"])
        ],
        [
            .letter("a", hold: ["@", "à", "á", "â", "ä", "æ", "ã", "å", "ā"]),
            .letter("s", hold: ["#", "ß", "ś", "š", "ş"]),
            .letter("d", hold: ["$", "ð", "ď", "đ", "ḋ"]),
            .letter("f", hold: ["%", "ḟ"]),
            .letter("g", hold: ["&", "ğ", "ġ", "ģ"]),
            .letter("h", hold: ["-", "–", "ĥ", "ħ", "ḣ"]),
            .letter("j", hold: ["+", "ĵ"]),
            .letter("k", hold: ["(", "ƙ", "ḳ"]),
            .letter("l", hold: [")", "ł", "ĺ", "ľ", "ḷ"])
        ],
        [
            .shift,
            .letter("z", hold: ["*", "ž", "ź", "ż"]),
            .letter("x", hold: ["\"", "ẋ"]),
            .letter("c", hold: ["'", "ç", "ć", "č"]),
            .letter("v", hold: [":", "ṽ"]),
            .letter("b", hold: [";", "ɓ", "ƀ", "ḃ"]),
            .letter("n", hold: ["!", "ñ", "ń", "ň"]),
            .letter("m", hold: ["?", "—", "ṁ"]),
            .backspace
        ],
        [
            .switch123,
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
            .letter("-", hold: ["–", "—", "•"]), .letter("/", hold: ["\\"]),
            .letter(":"), .letter(";"), .letter("("), .letter(")"),
            .letter("$", hold: ["₽", "¥", "€", "¢", "£", "₩"]),
            .letter("&", hold: ["§"]), .letter("@"),
            .letter("\"", hold: ["”", "“", "„", "»", "«"])
        ],
        [
            .switchSym,
            .letter(".", hold: ["…"]), .letter(","), .letter("?", hold: ["¿"]),
            .letter("!", hold: ["¡"]), .letter("'", hold: ["’", "‘", "`"]),
            .backspace
        ],
        [
            .switchABC,
            .space,
            .returnKey
        ]
    ]

    static let symbols2: [[KeyDefinition]] = [
        [
            .letter("["), .letter("]"), .letter("{"), .letter("}"), .letter("#"),
            .letter("%", hold: ["‰"]), .letter("^"), .letter("*"), .letter("+"),
            .letter("=", hold: ["≠", "≈", "∞"])
        ],
        [
            .letter("_"), .letter("\\"), .letter("|"), .letter("~"), .letter("<"),
            .letter(">"), .letter("€"), .letter("£"), .letter("¥"), .letter("·")
        ],
        [
            .switch123,
            .letter(".", hold: ["…"]), .letter(","), .letter("?", hold: ["¿"]),
            .letter("!", hold: ["¡"]), .letter("'", hold: ["’", "‘", "`"]),
            .backspace
        ],
        [
            .switchABC,
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
