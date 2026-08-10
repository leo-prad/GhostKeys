import Foundation

/// Port of the JS reference engine in `ghostkeys-simulator.html`.
/// Provides next-word prediction (trigram/bigram + fallback to unigram/dictionary)
/// and single-word autocorrect (Damerau-Levenshtein + frequency + keyboard-adjacency).
final class PredictionEngine {
    let store: NGramStore
    let dict: PersonalDictionary

    init(store: NGramStore = NGramStore(), dict: PersonalDictionary = .shared) {
        self.store = store
        self.dict = dict
    }

    // MARK: - Constants

    private static let sep = NGramStore.sep

    // Adjacency map for QWERTY — used for autocorrect scoring.
    static let adjacentKeys: [Character: Set<Character>] = [
        "q": ["w", "a"],
        "w": ["q", "e", "a", "s"],
        "e": ["w", "r", "s", "d"],
        "r": ["e", "t", "d", "f"],
        "t": ["r", "y", "f", "g"],
        "y": ["t", "u", "g", "h"],
        "u": ["y", "i", "h", "j"],
        "i": ["u", "o", "j", "k"],
        "o": ["i", "p", "k", "l"],
        "p": ["o", "l"],
        "a": ["q", "w", "s", "z"],
        "s": ["w", "e", "a", "d", "z", "x"],
        "d": ["e", "r", "s", "f", "x", "c"],
        "f": ["r", "t", "d", "g", "c", "v"],
        "g": ["t", "y", "f", "h", "v", "b"],
        "h": ["y", "u", "g", "j", "b", "n"],
        "j": ["u", "i", "h", "k", "n", "m"],
        "k": ["i", "o", "j", "l", "m"],
        "l": ["o", "p", "k"],
        "z": ["a", "s", "x"],
        "x": ["z", "s", "d", "c"],
        "c": ["x", "d", "f", "v"],
        "v": ["c", "f", "g", "b"],
        "b": ["v", "g", "h", "n"],
        "n": ["b", "h", "j", "m"],
        "m": ["n", "j", "k"]
    ]

    // Common English contractions & shortcuts. Autocorrect fires these first.
    static let contractions: [String: String] = [
        "lets": "let's", "im": "I'm", "dont": "don't", "cant": "can't", "wont": "won't",
        "isnt": "isn't", "arent": "aren't", "wasnt": "wasn't", "werent": "weren't",
        "hasnt": "hasn't", "havent": "haven't", "hadnt": "hadn't", "couldnt": "couldn't",
        "wouldnt": "wouldn't", "shouldnt": "shouldn't", "youre": "you're", "theyre": "they're",
        "weve": "we've", "youve": "you've", "theyve": "they've", "ive": "I've",
        "whats": "what's", "thats": "that's", "theres": "there's", "heres": "here's",
        "ill": "I'll", "youll": "you'll", "theyll": "they'll",
        "idk": "I don't know", "omw": "On my way!", "brb": "Be right back!", "tbh": "to be honest"
    ]

    // Multi-word repairs — deliberate, conservative list.
    static let multiwordCorrections: [String: String] = [
        "alot": "a lot", "aswell": "as well", "atleast": "at least",
        "eachother": "each other", "infront": "in front", "upto": "up to",
        "couldof": "could have", "wouldof": "would have", "shouldof": "should have"
    ]

    // Built-in phrase bigrams to give minute-one predictions.
    private static let builtinPhrases = [
        "i am on my way",
        "let me know",
        "thank you so much",
        "see you soon",
        "sounds good to me",
        "what time works",
        "i will be there",
        "can you send",
        "looking forward to it",
        "how are you doing",
        "have a great day",
        "talk to you later",
        "i do not know",
        "i think that",
        "would you like",
        "do you want",
        "please let me know"
    ]

    private static let builtinBigramCounts: [String: Int] = {
        var map: [String: Int] = [:]
        for phrase in builtinPhrases {
            let words = phrase.split(separator: " ").map(String.init)
            for i in 1..<words.count {
                let key = NGramStore.ngramKey(words[i-1], words[i])
                map[key, default: 0] += 1
            }
        }
        return map
    }()

    // MARK: - Tokenisation of context

    /// Tokenise a text-document context string into lowercase words.
    static func tokenize(_ text: String) -> [String] {
        var current = ""
        var out: [String] = []
        for ch in text {
            if ch.isLetter || ch == "'" {
                current.append(Character(String(ch).lowercased()))
            } else {
                if !current.isEmpty { out.append(current); current = "" }
            }
        }
        if !current.isEmpty { out.append(current) }
        return out
    }

    static let profanityBlocklist: Set<String> = [
        "ass", "shit", "fuck", "bitch", "cunt", "dick", "pussy", "bastard", "cock", "whore", "slut", "nigger", "faggot", "arse", "bollocks", "bugger", "wanker"
    ]

    // MARK: - Prediction

    /// Return up to 3 candidate suggestions for the current caret position.
    /// `contextBefore` is the text before the caret (e.g. `documentContextBeforeInput`).
    /// `partial` is the word currently being typed (unfinished token, if any).
    func predict(contextBefore: String, partial: String? = nil) -> [PredictionResult] {
        let trimmedBefore = contextBefore.trimmingCharacters(in: .whitespacesAndNewlines)
        if (contextBefore.isEmpty || trimmedBefore.isEmpty) && (partial == nil || partial?.isEmpty == true) {
            return [
                PredictionResult(word: "I", score: 10.0),
                PredictionResult(word: "The", score: 9.0),
                PredictionResult(word: "And", score: 8.0)
            ]
        }

        var tokens = PredictionEngine.tokenize(contextBefore)
        var partialWord = partial?.lowercased() ?? ""

        // If `partial` is nil, infer it from the trailing token of contextBefore
        // when it wasn't followed by whitespace.
        if partial == nil, let last = contextBefore.last, last.isLetter, let t = tokens.last {
            partialWord = t
            tokens.removeLast()
        }

        let c2 = tokens.last
        let c1 = tokens.dropLast().last

        var scores: [String: Double] = [:]

        func add(_ w: String, base: Double, t: Double) {
            let lower = w.lowercased()
            if partialWord.isEmpty && PredictionEngine.profanityBlocklist.contains(lower) { return }
            if !partialWord.isEmpty && !lower.hasPrefix(partialWord) { return }
            if lower == partialWord { return }
            scores[w, default: 0] += base * NGramStore.recencyBoost(t)
        }

        // Trigram
        if let c1 = c1, let c2 = c2 {
            let prefix = NGramStore.ngramKey(c1, c2) + PredictionEngine.sep
            for (k, e) in store.tri where k.hasPrefix(prefix) {
                let w = String(k.dropFirst(prefix.count))
                add(w, base: Double(e.f) * 3.0, t: e.t)
            }
        }
        // Bigram (learned)
        if let c2 = c2 {
            let prefix = c2 + PredictionEngine.sep
            for (k, e) in store.bi where k.hasPrefix(prefix) {
                let w = String(k.dropFirst(prefix.count))
                add(w, base: Double(e.f) * 2.0, t: e.t)
            }
            // Built-in phrase bigrams
            for (k, f) in PredictionEngine.builtinBigramCounts where k.hasPrefix(prefix) {
                let w = String(k.dropFirst(prefix.count))
                add(w, base: Double(f) * 1.2, t: NGramStore.nowDays)
            }
        }
        // Unigram: learned words (only if dictionary-valid or accepted).
        for (w, e) in store.uni {
            if !(dict.contains(w) || store.accepted[w] != nil) { continue }
            add(w, base: Double(e.f) * 1.0, t: e.t)
        }
        // Prefix completions from dictionary if user is typing.
        if !partialWord.isEmpty {
            var count = 0
            for w in dict.orderedWords {
                if w.hasPrefix(partialWord) && w != partialWord && scores[w] == nil {
                    scores[w] = 0.4 * NGramStore.recencyBoost(NGramStore.nowDays)
                    count += 1
                    if count >= 30 { break }
                }
            }
        }

        let ranked = scores
            .map { PredictionResult(word: $0.key, score: $0.value) }
            .sorted { $0.score > $1.score }
        return Array(ranked.prefix(3))
    }

    // MARK: - Autocorrect

    /// Return the corrected form of `word` or nil if no confident correction.
    func autocorrect(_ word: String, contextBefore: String = "") -> String? {
        guard !word.isEmpty, !shouldSkipAutocorrect(word) else { return nil }
        let lw = word.lowercased()

        if let m = PredictionEngine.multiwordCorrections[lw] { return preserveCasing(word, m) }
        if let c = PredictionEngine.contractions[lw] { return preserveCasing(word, c) }

        if isValidWordForm(lw) { return nil }

        if let dup = repairDuplicateLetter(lw).first(where: { isValidWordForm($0) }) {
            return preserveCasing(word, dup)
        }

        struct Cand { let w: String; let score: Double }
        var ranked: [Cand] = []

        let contextTokens = PredictionEngine.tokenize(contextBefore)
        let c2 = contextTokens.last
        let c1 = contextTokens.dropLast().last

        let lwCount = lw.count
        let lwChars = Array(lw)
        guard let lwFirst = lwChars.first else { return nil }

        func evaluateCandidate(_ cand: String) {
            let candCount = cand.count
            if abs(candCount - lwCount) > 2 { return }
            let candChars = Array(cand)
            if candChars.first != lwFirst && abs(candCount - lwCount) > 1 { return }
            if store.rejected[lw + PredictionEngine.sep + cand] != nil { return }

            let d = damerau(lwChars, candChars)
            if d > 2 { return }

            let swapped: Bool = (lwCount == candCount && d == 1 && {
                for i in 0..<(lwChars.count - 1) {
                    if lwChars[i] == candChars[i+1] && lwChars[i+1] == candChars[i] { return true }
                }
                return false
            }())

            let rank = dict.indexByWord[cand] ?? dict.orderedWords.count
            let frequency: Double
            if let f = dict.baseFrequency[cand] {
                frequency = log10(Double(f) + 1.0)
            } else {
                frequency = 4.5 * (1.0 - log(Double(rank) + 1.0) / log(Double(dict.orderedWords.count) + 1.0))
            }
            let personal = Double(store.accepted[cand]?.f ?? 0) * 0.8
            let learnedTypo = Double(store.typos[lw + PredictionEngine.sep + cand]?.f ?? 0) * 2.2
            let ctx = contextScore(candidate: cand, c1: c1, c2: c2)
            let bonus = keyboardBonus(typed: lw, candidate: cand)
            let score = frequency + personal + learnedTypo + ctx - Double(d) * 3.0 + (swapped ? 1.4 : 0) + bonus
            ranked.append(Cand(w: cand, score: score))
        }

        for cand in dict.orderedWords {
            evaluateCandidate(cand)
        }
        for cand in store.accepted.keys where dict.indexByWord[cand] == nil {
            evaluateCandidate(cand)
        }

        ranked.sort { $0.score > $1.score }
        guard let best = ranked.first else { return nil }
        let runnerUp = ranked.dropFirst().first
        if best.score < 0.7 { return nil }
        if let r = runnerUp, best.score - r.score < 0.25 { return nil }
        return preserveCasing(word, best.w)
    }

    // MARK: - Helpers

    private func shouldSkipAutocorrect(_ word: String) -> Bool {
        if word.count < 2 { return true }
        if word.rangeOfCharacter(from: .decimalDigits) != nil { return true }
        if word.contains("@") || word.contains("/") || word.contains("_") || word.contains("\\") { return true }
        let lower = word.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("www.") { return true }
        if word.count > 1, word == word.uppercased() { return true } // all-caps preserved
        return false
    }

    private func isValidWordForm(_ lw: String) -> Bool {
        if lw.isEmpty { return false }
        if PredictionEngine.contractions[lw] != nil { return false }
        if dict.contains(lw) || store.accepted[lw] != nil { return true }

        // -s / -es
        if lw.hasSuffix("s") && !lw.hasSuffix("ss") {
            let stem1 = String(lw.dropLast())
            if dict.contains(stem1) || store.accepted[stem1] != nil { return true }
            if lw.hasSuffix("es") {
                let stem2 = String(lw.dropLast(2))
                if dict.contains(stem2) || store.accepted[stem2] != nil { return true }
            }
        }
        // -ing
        if lw.hasSuffix("ing") && lw.count > 4 {
            let stem = String(lw.dropLast(3))
            if dict.contains(stem) || store.accepted[stem] != nil { return true }
            let stemE = stem + "e"
            if dict.contains(stemE) || store.accepted[stemE] != nil { return true }
            if stem.count > 2, stem.last == stem.dropLast().last {
                let stemSingle = String(stem.dropLast())
                if dict.contains(stemSingle) || store.accepted[stemSingle] != nil { return true }
            }
        }
        // -ed
        if lw.hasSuffix("ed") && lw.count > 3 {
            let stem = String(lw.dropLast(2))
            if dict.contains(stem) || store.accepted[stem] != nil { return true }
            let stemD = String(lw.dropLast())
            if dict.contains(stemD) || store.accepted[stemD] != nil { return true }
        }
        // -ly
        if lw.hasSuffix("ly") && lw.count > 3 {
            let stem = String(lw.dropLast(2))
            if dict.contains(stem) || store.accepted[stem] != nil { return true }
        }
        // -er / -est
        if (lw.hasSuffix("er") || lw.hasSuffix("est")) && lw.count > 3 {
            let cut = lw.hasSuffix("er") ? 2 : 3
            let stem = String(lw.dropLast(cut))
            if dict.contains(stem) || store.accepted[stem] != nil { return true }
        }
        return false
    }

    /// Remove one character from a repeated run — "goodd" -> "good", "corrrected" -> "corrected".
    private func repairDuplicateLetter(_ s: String) -> [String] {
        var out: [String] = []
        let a = Array(s)
        for i in 0..<(a.count - 1) where a[i] == a[i+1] {
            var b = a; b.remove(at: i)
            let candidate = String(b)
            if !out.contains(candidate) { out.append(candidate) }
        }
        return out
    }

    private func contextScore(candidate: String, c1: String?, c2: String?) -> Double {
        var score: Double = 0
        if let c2 = c2, let e = store.bi[NGramStore.ngramKey(c2, candidate)] {
            score += log(Double(e.f) + 1.0) * 3.5 * NGramStore.recencyBoost(e.t)
        }
        if let c1 = c1, let c2 = c2, let e = store.tri[NGramStore.ngramKey(c1, c2, candidate)] {
            score += log(Double(e.f) + 1.0) * 5.5 * NGramStore.recencyBoost(e.t)
        }
        return score
    }

    private func keyboardBonus(typed: String, candidate: String) -> Double {
        guard typed.count == candidate.count else { return 0 }
        var bonus: Double = 0
        let ta = Array(typed), ca = Array(candidate)
        for i in 0..<ta.count {
            if ta[i] != ca[i] {
                let a = ta[i], b = ca[i]
                if let neigh = PredictionEngine.adjacentKeys[a], neigh.contains(b) {
                    bonus += 0.8
                }
            }
        }
        return min(1.6, bonus)
    }

    /// Damerau-Levenshtein — recognises adjacent-swap typos (nto -> not = distance 1).
    private func damerau(_ ac: [Character], _ bc: [Character]) -> Int {
        let m = ac.count, n = bc.count
        if abs(m - n) > 2 { return 3 }
        var dp0 = Array(repeating: 0, count: n + 1)
        var dp1 = Array(repeating: 0, count: n + 1)
        var dp2 = Array(repeating: 0, count: n + 1)

        for j in 0...n { dp1[j] = j }

        for i in 1...m {
            dp2[0] = i
            for j in 1...n {
                let cost = (ac[i-1] == bc[j-1]) ? 0 : 1
                var val = min(dp1[j] + 1, dp2[j-1] + 1, dp1[j-1] + cost)
                if i > 1, j > 1, ac[i-1] == bc[j-2], ac[i-2] == bc[j-1] {
                    val = min(val, dp0[j-2] + 1)
                }
                dp2[j] = val
            }
            dp0 = dp1
            dp1 = dp2
        }
        return dp1[n]
    }

    /// Preserve leading capitalization from `typed` in the correction.
    private func preserveCasing(_ typed: String, _ correction: String) -> String {
        guard let first = typed.first, first.isUppercase,
              typed.dropFirst().allSatisfy({ $0.isLowercase || $0.isPunctuation }) else {
            return correction
        }
        guard let cfirst = correction.first else { return correction }
        return cfirst.uppercased() + correction.dropFirst()
    }
}
