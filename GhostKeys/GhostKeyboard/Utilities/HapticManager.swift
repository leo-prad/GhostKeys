import UIKit

final class HapticManager {
    static let shared = HapticManager()

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)

    private init() {
        light.prepare()
        medium.prepare()
        rigid.prepare()
    }

    private var enabled: Bool { SharedDefaults.bool(SharedDefaults.Key.hapticsEnabled, default: true) }

    func tap()    { guard enabled else { return }; light.impactOccurred() }
    func delete() { guard enabled else { return }; medium.impactOccurred() }
    func shift()  { guard enabled else { return }; rigid.impactOccurred() }
}
