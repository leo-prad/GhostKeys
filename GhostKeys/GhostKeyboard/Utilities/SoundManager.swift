import AudioToolbox

enum SoundManager {
    // Standard iOS keyboard click sound IDs.
    private static let tapSoundId: SystemSoundID = 1104
    private static let deleteSoundId: SystemSoundID = 1155
    private static let modifierSoundId: SystemSoundID = 1156

    private static var enabled: Bool {
        SharedDefaults.bool(SharedDefaults.Key.soundEnabled, default: false)
    }

    static func tap()      { guard enabled else { return }; AudioServicesPlaySystemSound(tapSoundId) }
    static func delete()   { guard enabled else { return }; AudioServicesPlaySystemSound(deleteSoundId) }
    static func modifier() { guard enabled else { return }; AudioServicesPlaySystemSound(modifierSoundId) }
}
