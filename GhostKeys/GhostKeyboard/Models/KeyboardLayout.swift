import Foundation

enum KeyboardLayout {
    // Letters layout — Gboard-style long-press mapping (numbers on top row, symbols/accents on lower rows).
    static let letters: [[KeyDefinition]] = [
        [
            .letter("q", hold: ["1"]),
            .letter("w", hold: ["2", "ŵ", "ẃ", "ẁ", "ẇ"]),
            .letter("e", hold: ["3", "è", "é", "ê", "ë", "ē", "ė", "ę", "ě", "ĕ"]),
            .letter("r", hold: ["4", "ř", "ŕ", "ṙ", "ŗ"]),
            .letter("t", hold: ["5", "þ", "ť", "ţ", "ț", "ṫ", "ṭ"]),
            .letter("y", hold: ["6", "ÿ", "ý", "ŷ", "ỳ", "ȳ"]),
            .letter("u", hold: ["7", "ù", "ú", "û", "ü", "ū", "ų", "ű", "ǔ", "ŭ"]),
            .letter("i", hold: ["8", "ì", "í", "î", "ï", "ī", "į", "ı", "ĭ"]),
            .letter("o", hold: ["9", "ò", "ó", "ô", "ö", "ø", "õ", "œ", "ō", "ő", "ǒ"]),
            .letter("p", hold: ["0", "ṗ", "ƥ"])
        ],
        [
            .letter("a", hold: ["@", "à", "á", "â", "ä", "æ", "ã", "å", "ā", "ą", "ǎ", "ă"]),
            .letter("s", hold: ["#", "ß", "ś", "š", "ş", "ŝ", "ș", "ṡ"]),
            .letter("d", hold: ["$", "ð", "ď", "đ", "ḋ", "ḍ"]),
            .letter("f", hold: ["%", "ḟ", "ƒ"]),
            .letter("g", hold: ["&", "ğ", "ġ", "ģ", "ĝ", "ǧ"]),
            .letter("h", hold: ["-", "–", "ĥ", "ħ", "ḣ", "ḥ"]),
            .letter("j", hold: ["+", "ĵ", "ǰ"]),
            .letter("k", hold: ["(", "ƙ", "ḳ", "ķ", "ǩ"]),
            .letter("l", hold: [")", "ł", "ĺ", "ľ", "ļ", "ḷ", "ŀ"])
        ],
        [
            .shift,
            .letter("z", hold: ["*", "ž", "ź", "ż", "ẑ", "ẓ"]),
            .letter("x", hold: ["\"", "ẋ", "ẍ"]),
            .letter("c", hold: ["'", "ç", "ć", "č", "ĉ", "ċ"]),
            .letter("v", hold: [":", "ṽ", "ṿ"]),
            .letter("b", hold: [";", "ɓ", "ƀ", "ḃ", "ḅ", "ḇ"]),
            .letter("n", hold: ["!", "ñ", "ń", "ň", "ņ", "ṅ", "ṇ"]),
            .letter("m", hold: ["?", "—", "ṁ", "ṃ"]),
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
            .letter("1", hold: ["¹", "①", "½", "⅓", "¼"]),
            .letter("2", hold: ["²", "②", "⅔"]),
            .letter("3", hold: ["³", "③", "¾"]),
            .letter("4", hold: ["⁴", "④"]),
            .letter("5", hold: ["⁵", "⑤", "⅕"]),
            .letter("6", hold: ["⁶", "⑥"]),
            .letter("7", hold: ["⁷", "⑦"]),
            .letter("8", hold: ["⁸", "⑧"]),
            .letter("9", hold: ["⁹", "⑨"]),
            .letter("0", hold: ["⁰", "⓪", "°"])
        ],
        [
            .letter("-", hold: ["–", "—", "•", "·", "±"]),
            .letter("/", hold: ["\\", "÷"]),
            .letter(":", hold: ["∶"]),
            .letter(";", hold: ["·"]),
            .letter("(", hold: ["[", "{", "<"]),
            .letter(")", hold: ["]", "}", ">"]),
            .letter("$", hold: ["₽", "¥", "€", "¢", "£", "₩", "₹", "₺", "₫"]),
            .letter("&", hold: ["§", "¶", "†", "‡"]),
            .letter("@", hold: ["№"]),
            .letter("\"", hold: ["”", "“", "„", "»", "«", "‟"])
        ],
        [
            .switchSym,
            .letter(".", hold: ["…", "·"]),
            .letter(",", hold: ["‚"]),
            .letter("?", hold: ["¿", "‽"]),
            .letter("!", hold: ["¡", "‽"]),
            .letter("'", hold: ["’", "‘", "`", "′"]),
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
            .letter("[", hold: ["("]),
            .letter("]", hold: [")"]),
            .letter("{", hold: ["⟨"]),
            .letter("}", hold: ["⟩"]),
            .letter("#", hold: ["№", "♯"]),
            .letter("%", hold: ["‰", "‱"]),
            .letter("^", hold: ["↑", "°"]),
            .letter("*", hold: ["×", "•", "★", "☆"]),
            .letter("+", hold: ["±", "⁺"]),
            .letter("=", hold: ["≠", "≈", "≤", "≥", "∞", "≡"])
        ],
        [
            .letter("_", hold: ["—"]),
            .letter("\\", hold: ["/"]),
            .letter("|", hold: ["¦", "‖"]),
            .letter("~", hold: ["≈"]),
            .letter("<", hold: ["≤", "«", "⟨"]),
            .letter(">", hold: ["≥", "»", "⟩"]),
            .letter("€", hold: ["¢"]),
            .letter("£", hold: ["₤"]),
            .letter("¥", hold: ["¢"]),
            .letter("·", hold: ["•", "◦", "∙"])
        ],
        [
            .switch123,
            .letter(".", hold: ["…", "·"]),
            .letter(",", hold: ["‚"]),
            .letter("?", hold: ["¿", "‽"]),
            .letter("!", hold: ["¡", "‽"]),
            .letter("'", hold: ["’", "‘", "`", "′"]),
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
