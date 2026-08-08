import Foundation

enum SharedDefaults {
    static let store: UserDefaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard

    enum Key {
        static let hapticsEnabled = "hapticsEnabled"
        static let soundEnabled = "soundEnabled"
        static let autocorrectEnabled = "autocorrectEnabled"
        static let learnedWords = "learnedWords"
        static let totalKeystrokes = "totalKeystrokes"
    }

    static func bool(_ key: String, default def: Bool) -> Bool {
        if store.object(forKey: key) == nil { return def }
        return store.bool(forKey: key)
    }
}
