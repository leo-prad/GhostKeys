import Foundation

/// Loads the bundled base dictionary from `lexicon.json` (top ~8k English words
/// with subtitle-corpus frequencies), plus a small hard-coded set of common
/// keyboard-era neologisms.
final class PersonalDictionary {
    static let shared = PersonalDictionary()

    /// Ordered list of dictionary words. Earlier indices are more common.
    let orderedWords: [String]
    /// Lookup: word -> position (lower = more common).
    let indexByWord: [String: Int]
    /// Set for O(1) membership tests.
    let wordSet: Set<String>
    /// Base subtitle-frequency counts from FrequencyWords en_50k.
    let baseFrequency: [String: Int]

    private init() {
        var entries: [(String, Int)] = []
        if let url = Bundle(for: PersonalDictionary.self).url(forResource: "lexicon", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[Any]] {
            for pair in arr {
                if pair.count == 2, let w = pair[0] as? String, let f = pair[1] as? Int {
                    entries.append((w, f))
                }
            }
        }
        let extras = ["im", "dont", "cant", "wont", "isnt", "arent", "youre", "theyre", "ive", "youll", "wifi", "username", "password"]
        var seen = Set<String>()
        var ordered: [String] = []
        var freq: [String: Int] = [:]
        for (w, f) in entries {
            if !seen.contains(w) { seen.insert(w); ordered.append(w) }
            freq[w] = f
        }
        for w in extras where !seen.contains(w) { seen.insert(w); ordered.append(w) }
        var idx: [String: Int] = [:]
        for (i, w) in ordered.enumerated() { idx[w] = i }
        self.orderedWords = ordered
        self.indexByWord = idx
        self.wordSet = seen
        self.baseFrequency = freq
    }

    func contains(_ w: String) -> Bool { wordSet.contains(w) }
}
