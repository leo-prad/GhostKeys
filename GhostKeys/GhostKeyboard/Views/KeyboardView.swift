import UIKit

protocol KeyboardViewDelegate: AnyObject {
    func keyboardView(_ view: KeyboardView, didTap definition: KeyDefinition)
    func keyboardView(_ view: KeyboardView, didHold definition: KeyDefinition, resolved character: String)
    func keyboardViewBackspaceRepeat(_ view: KeyboardView)
    func keyboardViewNextKeyboardEvent(_ view: KeyboardView, sender: UIView, event: UIEvent?)
}

/// Main keyboard container. Lays out rows for the current page.
final class KeyboardView: UIView {
    weak var delegate: KeyboardViewDelegate?
    let state: KeyboardState
    private(set) var theme: KeyboardTheme

    private var rows: [[KeyButton]] = []
    private var currentPage: KeyboardPage = .letters

    // Popup
    private var popup: PopupKeyView?
    private var popupOwner: KeyButton?
    private var holdTimer: Timer?
    private var holdThreshold: TimeInterval {
        return max(0.15, SharedDefaults.double(SharedDefaults.Key.holdDelayMs, default: 350) / 1000.0)
    }

    // Backspace repeat
    private var backspaceTimer: Timer?

    init(state: KeyboardState, theme: KeyboardTheme) {
        self.state = state
        self.theme = theme
        super.init(frame: .zero)
        backgroundColor = theme.keyboardBackground
        buildRows()
    }
    required init?(coder: NSCoder) { fatalError() }

    func apply(theme: KeyboardTheme) {
        self.theme = theme
        backgroundColor = theme.keyboardBackground
        for row in rows { for k in row { k.apply(theme: theme) } }
        refreshDisplayStrings()
    }

    func refreshForStateChange() {
        if state.page != currentPage { buildRows() }
        else { refreshDisplayStrings() }
    }

    private func buildRows() {
        rows.forEach { $0.forEach { $0.removeFromSuperview() } }
        rows.removeAll()
        currentPage = state.page
        let defs = KeyboardLayout.rows(for: state.page)
        for row in defs {
            var built: [KeyButton] = []
            for def in row {
                let btn = KeyButton(definition: def, theme: theme)
                btn.delegate = self
                addSubview(btn)
                built.append(btn)
            }
            rows.append(built)
        }
        refreshDisplayStrings()
        setNeedsLayout()
    }

    private func refreshDisplayStrings() {
        for row in rows {
            for k in row {
                switch k.definition.type {
                case .letter:
                    if state.page == .letters {
                        k.displayString = state.isShifted ? k.definition.shifted : k.definition.primary
                    } else {
                        k.displayString = k.definition.primary
                    }
                case .shift:
                    k.displayString = state.shiftMode == .capsLock ? "⇪" : "⇧"
                case .switchMode:
                    // Set label per context (123 vs ABC vs #+=).
                    switch state.page {
                    case .letters:  k.displayString = "123"
                    case .symbols1: k.displayString = k.definition.primary  // ABC or #+=
                    case .symbols2: k.displayString = k.definition.primary
                    }
                default:
                    k.displayString = k.definition.primary
                }
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        let h = bounds.height
        guard w > 0, h > 0, !rows.isEmpty else { return }

        let hSpacing: CGFloat = 6
        let vSpacing: CGFloat = 6.5
        let sideMargin: CGFloat = 3
        let topMargin: CGFloat = 3
        let bottomMargin: CGFloat = 3

        let rowH = (h - topMargin - bottomMargin - vSpacing * CGFloat(rows.count - 1)) / CGFloat(rows.count)

        // Derive canonical key width from 10-column row
        let usableW = w - sideMargin * 2
        let baseW = (usableW - hSpacing * 9) / 10.0

        for (r, row) in rows.enumerated() {
            let y = topMargin + CGFloat(r) * (rowH + vSpacing)

            // For rows containing a .space, stretch space to fill available width.
            if let spaceIdx = row.firstIndex(where: { $0.definition.type == .space }) {
                var fixed: CGFloat = 0
                for (i, k) in row.enumerated() where i != spaceIdx {
                    fixed += k.definition.widthMultiplier * baseW
                }
                let spaceW = usableW - fixed - CGFloat(row.count - 1) * hSpacing
                var x = sideMargin
                for (i, k) in row.enumerated() {
                    let keyW = (i == spaceIdx) ? spaceW : (k.definition.widthMultiplier * baseW)
                    k.frame = CGRect(x: x, y: y, width: keyW, height: rowH)
                    x += keyW + hSpacing
                }
                continue
            }

            // Row 3 of Letters page (shift + 7 letters + backspace): stretch shift and backspace to touch side margins
            let isLettersRow3 = (r == 2 && state.page == .letters && row.first?.definition.type == .shift)

            if isLettersRow3 && row.count > 2 {
                let middleCount = row.count - 2
                let totalSpacing = CGFloat(row.count - 1) * hSpacing
                let sideKeyW = (usableW - totalSpacing - CGFloat(middleCount) * baseW) / 2.0

                var x = sideMargin
                for (i, k) in row.enumerated() {
                    let keyW = (i == 0 || i == row.count - 1) ? sideKeyW : baseW
                    k.frame = CGRect(x: x, y: y, width: keyW, height: rowH)
                    x += keyW + hSpacing
                }
                continue
            }

            // Standard layout (10 keys, 9 keys centered, or symbols row 3 centered with 1.35 multiplier for side keys)
            var totalMul: CGFloat = 0
            for k in row { totalMul += k.definition.widthMultiplier }
            let totalSpacing = CGFloat(row.count - 1) * hSpacing
            let rowWidth = totalMul * baseW + totalSpacing

            var x = sideMargin + (usableW - rowWidth) / 2.0
            for k in row {
                let keyW = k.definition.widthMultiplier * baseW
                k.frame = CGRect(x: x, y: y, width: keyW, height: rowH)
                x += keyW + hSpacing
            }
        }
    }

    // MARK: - Popup helpers
    private func showPopup(for key: KeyButton) {
        cancelPopup()
        let chars = key.definition.holdCharacters
        guard !chars.isEmpty else { return }

        let popup = PopupKeyView(theme: theme)
        popup.configure(holdCharacters: chars)
        popup.translatesAutoresizingMaskIntoConstraints = false
        addSubview(popup)

        let hasTop = chars.contains(where: { !($0.first?.isNumber == true || "!@#$%^&*()-_=+[]{}|;:'\",.<>/?~".contains($0.first ?? " ")) })
        let hasBottom = chars.contains(where: { $0.first?.isNumber == true || "!@#$%^&*()-_=+[]{}|;:'\",.<>/?~".contains($0.first ?? " ") })
        let isTwoRows = hasTop && hasBottom

        let popupHeight: CGFloat = isTwoRows ? 82 : 46
        let colCount = isTwoRows ? max(1, chars.count - 1) : chars.count
        let popupWidth: CGFloat = min(bounds.width - 12, CGFloat(colCount) * 40 + 16)

        var frame = CGRect(x: key.frame.midX - popupWidth / 2,
                           y: key.frame.minY - popupHeight - 6,
                           width: popupWidth, height: popupHeight)
        // Keep inside keyboard bounds horizontally
        if frame.minX < 4 { frame.origin.x = 4 }
        if frame.maxX > bounds.width - 4 { frame.origin.x = bounds.width - 4 - frame.width }
        popup.translatesAutoresizingMaskIntoConstraints = true
        popup.frame = frame
        self.popup = popup
        self.popupOwner = key
        HapticManager.shared.tap()
    }

    private func cancelPopup() {
        popup?.removeFromSuperview()
        popup = nil
        popupOwner = nil
    }

    // MARK: - Backspace repeat
    private func startBackspaceRepeat() {
        stopBackspaceRepeat()
        let speed = max(0.02, SharedDefaults.double(SharedDefaults.Key.backspaceSpeedMs, default: 80) / 1000.0)
        backspaceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.backspaceTimer = Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.delegate?.keyboardViewBackspaceRepeat(self)
            }
        }
    }

    private func stopBackspaceRepeat() {
        backspaceTimer?.invalidate()
        backspaceTimer = nil
    }
}

// MARK: - KeyButtonDelegate

extension KeyboardView: KeyButtonDelegate {
    func keyButton(_ button: KeyButton, didBegin touch: UITouch) {
        holdTimer?.invalidate()

        if button.definition.type == .backspace {
            startBackspaceRepeat()
            return
        }
        if button.definition.type == .nextKeyboard {
            delegate?.keyboardViewNextKeyboardEvent(self, sender: button, event: nil)
            return
        }

        if !button.definition.holdCharacters.isEmpty {
            holdTimer = Timer.scheduledTimer(withTimeInterval: holdThreshold, repeats: false) { [weak self, weak button] _ in
                guard let self = self, let button = button else { return }
                self.showPopup(for: button)
            }
        }
    }

    func keyButton(_ button: KeyButton, didMove touch: UITouch) {
        if let popup = popup, popupOwner === button {
            let p = touch.location(in: popup)
            popup.highlightIndex(forXInSelf: p.x)
        }
    }

    func keyButton(_ button: KeyButton, didEnd touch: UITouch, cancelled: Bool) {
        holdTimer?.invalidate()
        holdTimer = nil

        if button.definition.type == .backspace {
            stopBackspaceRepeat()
            if !cancelled {
                delegate?.keyboardView(self, didTap: button.definition)
            }
            return
        }

        if let popup = popup, popupOwner === button {
            if !cancelled, let ch = popup.selectedCharacter {
                delegate?.keyboardView(self, didHold: button.definition, resolved: ch)
            }
            cancelPopup()
            return
        }

        if !cancelled {
            delegate?.keyboardView(self, didTap: button.definition)
        }
    }
}
