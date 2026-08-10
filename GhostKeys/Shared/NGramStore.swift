import Foundation

/// Persistent n-gram store backed by JSON in the App Group container.
/// Kept in-memory for hot access; flushed with a debounced timer.
final class NGramStore {
    struct Entry: Codable { var f: Int; var t: Double }   // frequency, last-used (days-since-epoch)

    private(set) var uni: [String: Entry] = [:]
    private(set) var bi: [String: Entry] = [:]
    private(set) var tri: [String: Entry] = [:]
    private(set) var accepted: [String: Entry] = [:]     // words user deliberately accepted
    private(set) var rejected: [String: Double] = [:]    // "typed\u{1F}candidate" -> timestamp
    private(set) var typos: [String: Entry] = [:]        // "typed\u{1F}corrected" -> frequency
    private(set) var keystrokes: Int = 0

    private struct Persisted: Codable {
        var uni: [String: Entry]
        var bi: [String: Entry]
        var tri: [String: Entry]
        var accepted: [String: Entry]
        var rejected: [String: Double]
        var typos: [String: Entry]
        var keystrokes: Int
    }

    private let fileURL: URL
    private var saveWorkItem: DispatchWorkItem?

    init() {
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = container.appendingPathComponent("ghostkeys_ngrams_v3.json")
        load()
    }

    static let sep = "\u{001F}"
    static func ngramKey(_ words: String...) -> String { words.joined(separator: sep) }

    static var nowDays: Double { Date().timeIntervalSince1970 / 86_400.0 }

    static func recencyBoost(_ t: Double) -> Double {
        let d = max(0, nowDays - t)
        return 1.0 + (2.0 / (1.0 + d))
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode(Persisted.self, from: data) else { return }
        uni = saved.uni; bi = saved.bi; tri = saved.tri
        accepted = saved.accepted; rejected = saved.rejected
        typos = saved.typos; keystrokes = saved.keystrokes
    }

    func scheduleSave() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWorkItem = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func saveNow() {
        let persisted = Persisted(uni: uni, bi: bi, tri: tri, accepted: accepted, rejected: rejected, typos: typos, keystrokes: keystrokes)
        guard let data = try? JSONEncoder().encode(persisted) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func bump(_ map: inout [String: Entry], _ key: String) {
        var e = map[key] ?? Entry(f: 0, t: NGramStore.nowDays)
        e.f += 1
        e.t = NGramStore.nowDays
        map[key] = e
    }

    func learn(words: [String]) {
        for i in 0..<words.count {
            let w = words[i]
            guard !w.isEmpty else { continue }
            bump(&uni, w)
            if i >= 1, !words[i-1].isEmpty { bump(&bi, NGramStore.ngramKey(words[i-1], w)) }
            if i >= 2, !words[i-1].isEmpty, !words[i-2].isEmpty {
                bump(&tri, NGramStore.ngramKey(words[i-2], words[i-1], w))
            }
        }
        scheduleSave()
    }

    func recordKeystroke() { keystrokes += 1; scheduleSave() }

    func accept(word: String) {
        guard !word.isEmpty else { return }
        bump(&accepted, word.lowercased()); scheduleSave()
    }

    func rejectCorrection(typed: String, candidate: String) {
        guard !typed.isEmpty, !candidate.isEmpty else { return }
        rejected[typed.lowercased() + NGramStore.sep + candidate.lowercased()] = NGramStore.nowDays
        scheduleSave()
    }

    func learnTypo(typed: String, corrected: String) {
        let t = typed.lowercased(), c = corrected.lowercased()
        guard !t.isEmpty, !c.isEmpty, t != c else { return }
        bump(&typos, t + NGramStore.sep + c); scheduleSave()
    }

    func getLearnedWords() -> [String] {
        let set = Set(uni.keys).union(accepted.keys)
        return Array(set).sorted()
    }

    func addWord(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }
        bump(&uni, trimmed)
        bump(&accepted, trimmed)
        scheduleSave()
    }

    func removeWord(_ word: String) {
        let lower = word.lowercased()
        uni.removeValue(forKey: lower)
        accepted.removeValue(forKey: lower)
        scheduleSave()
    }

    func clearAll() {
        uni = [:]; bi = [:]; tri = [:]; accepted = [:]; rejected = [:]; typos = [:]; keystrokes = 0
        scheduleSave()
    }
}
