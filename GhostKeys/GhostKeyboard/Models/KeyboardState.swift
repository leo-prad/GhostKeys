import Foundation

enum ShiftMode {
    case lowercase
    case uppercase   // one-shot
    case capsLock
}

enum KeyboardPage {
    case letters
    case symbols1
    case symbols2
}

final class KeyboardState {
    var shiftMode: ShiftMode = .uppercase   // iOS starts capitalized in an empty field
    var page: KeyboardPage = .letters

    var isShifted: Bool { shiftMode != .lowercase }

    func toggleShift() {
        switch shiftMode {
        case .lowercase: shiftMode = .uppercase
        case .uppercase: shiftMode = .lowercase
        case .capsLock:  shiftMode = .lowercase
        }
    }

    func enableCapsLock() { shiftMode = .capsLock }

    // Return to lowercase after a letter is inserted (unless caps lock is on).
    func resetShiftAfterLetter() {
        if shiftMode == .uppercase { shiftMode = .lowercase }
    }
}
