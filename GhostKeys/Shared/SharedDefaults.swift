import Foundation

struct TextReplacementItem: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var phrase: String
    var shortcut: String
}

enum SharedDefaults {
    static let store: UserDefaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard

    enum Key {
        static let hapticsEnabled = "hapticsEnabled"
        static let soundEnabled = "soundEnabled"
        static let autocorrectEnabled = "autocorrectEnabled"
        static let autoCapitalizationEnabled = "autoCapitalizationEnabled"
        static let charPreviewEnabled = "charPreviewEnabled"
        static let specialHapticsEnabled = "specialHapticsEnabled"
        static let doubleSpacePeriodEnabled = "doubleSpacePeriodEnabled"
        static let doubleSpacePeriodMs = "doubleSpacePeriodMs"
        static let holdDelayMs = "holdDelayMs"
        static let backspaceSpeedMs = "backspaceSpeedMs"
        static let glideTriggerMs = "glideTriggerMs"
        static let deleteGlideWordEnabled = "deleteGlideWordEnabled"
        static let learnedWords = "learnedWords"
        static let totalKeystrokes = "totalKeystrokes"
        static let textReplacements = "textReplacements"
        static let caseMatchReplacementsEnabled = "caseMatchReplacementsEnabled"
    }

    static func bool(_ key: String, default def: Bool) -> Bool {
        if store.object(forKey: key) == nil { return def }
        return store.bool(forKey: key)
    }

    static func double(_ key: String, default def: Double) -> Double {
        if store.object(forKey: key) == nil { return def }
        return store.double(forKey: key)
    }

    static func integer(_ key: String, default def: Int) -> Int {
        if store.object(forKey: key) == nil { return def }
        return store.integer(forKey: key)
    }

    static func getTextReplacements() -> [TextReplacementItem] {
        guard let data = store.data(forKey: Key.textReplacements),
              let items = try? JSONDecoder().decode([TextReplacementItem].self, from: data) else {
            let defaults = [
                TextReplacementItem(phrase: "On my way!", shortcut: "omw")
            ]
            saveTextReplacements(defaults)
            return defaults
        }
        return items
    }

    static func saveTextReplacements(_ items: [TextReplacementItem]) {
        if let data = try? JSONEncoder().encode(items) {
            store.set(data, forKey: Key.textReplacements)
        }
    }
}
