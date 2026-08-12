import UIKit

protocol KeyboardViewDelegate: AnyObject {
    func keyboardView(_ view: KeyboardView, didTap definition: KeyDefinition)
    func keyboardView(_ view: KeyboardView, didHold definition: KeyDefinition, resolved character: String)
    func keyboardView(_ view: KeyboardView, didGlide trace: [String])
    func keyboardViewBackspaceRepeat(_ view: KeyboardView)
    func keyboardView(_ view: KeyboardView, deleteWords count: Int)
    func keyboardViewNextKeyboardEvent(_ view: KeyboardView, sender: UIView, event: UIEvent?)
    /// Hold-space cursor drag lifecycle.
    func keyboardViewSpaceCursorBegan(_ view: KeyboardView)
    func keyboardViewSpaceCursorMove(_ view: KeyboardView, characterOffset: Int)
    func keyboardViewSpaceCursorEnded(_ view: KeyboardView)
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
    private var keyPreview: UIView?
    private var holdThreshold: TimeInterval {
        return max(0.15, SharedDefaults.double(SharedDefaults.Key.holdDelayMs, default: 350) / 1000.0)
    }

    // Backspace repeat
    private var backspaceTimer: Timer?
    private var touchStart = CGPoint.zero
    private var touchStartTimestamp: TimeInterval = 0
    private var lastTouchPoint = CGPoint.zero
    private var glideTrace: [String] = []
    private var glideDistance: CGFloat = 0
    private var glideActivated = false
    private var glidePoints: [CGPoint] = []
    private let glideLayer = CAShapeLayer()
    private var backspaceSwipeWords = 0

    // Hold-space cursor drag
    private var spaceHoldTimer: Timer?
    private var spaceCursorMode = false
    private var spaceCursorLastX: CGFloat = 0
    private static let spaceCursorPointsPerChar: CGFloat = 9

    init(state: KeyboardState, theme: KeyboardTheme) {
        self.state = state
        self.theme = theme
        super.init(frame: .zero)
        clipsToBounds = false
        backgroundColor = theme.keyboardBackground
        glideLayer.fillColor = UIColor.clear.cgColor
        glideLayer.strokeColor = theme.keyTextColor.withAlphaComponent(0.5).cgColor
        glideLayer.lineWidth = 7
        glideLayer.lineCap = .round
        glideLayer.lineJoin = .round
        buildRows()
    }
    required init?(coder: NSCoder) { fatalError() }

    func apply(theme: KeyboardTheme) {
        self.theme = theme
        backgroundColor = theme.keyboardBackground
        glideLayer.strokeColor = theme.keyTextColor.withAlphaComponent(0.5).cgColor
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

            // Row 3 touches both side margins. On the symbol pages, keep the
            // mode and delete keys at their normal modifier width and give the
            // remaining width to the punctuation keys, matching Apple's layout.
            let firstType = row.first?.definition.type
            let lastType = row.last?.definition.type
            let isRow3 = (r == 2 && (firstType == .shift || firstType == .switchMode) && lastType == .backspace)

            if isRow3 && row.count > 2 {
                let middleCount = row.count - 2
                let totalSpacing = CGFloat(row.count - 1) * hSpacing
                let sideKeyW: CGFloat
                let middleKeyW: CGFloat

                if firstType == .switchMode {
                    sideKeyW = row[0].definition.widthMultiplier * baseW
                    middleKeyW = (usableW - totalSpacing - sideKeyW * 2) / CGFloat(middleCount)
                } else {
                    middleKeyW = baseW
                    sideKeyW = (usableW - totalSpacing - CGFloat(middleCount) * middleKeyW) / 2.0
                }

                var x = sideMargin
                for (i, k) in row.enumerated() {
                    let keyW = (i == 0 || i == row.count - 1) ? sideKeyW : middleKeyW
                    k.frame = CGRect(x: x, y: y, width: keyW, height: rowH)
                    x += keyW + hSpacing
                }
                continue
            }

            // Standard layout (10 keys or 9 keys centered)
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

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Give delete the complete right-hand side of its row, including the
        // edge inset. There is no dead strip between the key and screen edge.
        if let backspaceRow = rows.first(where: { $0.contains(where: { $0.definition.type == .backspace }) }),
           let backspace = backspaceRow.first(where: { $0.definition.type == .backspace }) {
            let deleteRegion = CGRect(x: backspace.frame.minX - 14,
                                      y: backspace.frame.minY - 4,
                                      width: bounds.maxX - backspace.frame.minX + 14,
                                      height: backspace.frame.height + 8)
            if deleteRegion.contains(point) {
                let localPoint = convert(point, to: backspace)
                return backspace.hitTest(localPoint, with: event) ?? backspace
            }
        }

        // Apple-style forgiving row hit targets: every horizontal gap and the
        // empty side margins resolve to the nearest key in that visual row.
        // This makes the area immediately left of A behave as A, for example.
        for (index, row) in rows.enumerated() where !row.isEmpty {
            let rowMinY = index == 0
                ? row[0].frame.minY
                : (rows[index - 1][0].frame.maxY + row[0].frame.minY) / 2
            let rowMaxY = index == rows.count - 1
                ? row[0].frame.maxY
                : (row[0].frame.maxY + rows[index + 1][0].frame.minY) / 2
            guard point.y >= rowMinY, point.y <= rowMaxY else { continue }

            guard let nearest = row.min(by: {
                abs($0.frame.midX - point.x) < abs($1.frame.midX - point.x)
            }) else { break }
            let localPoint = convert(point, to: nearest)
            return nearest.hitTest(localPoint, with: event) ?? nearest
        }

        if let backspace = rows.joined().first(where: { $0.definition.type == .backspace }),
           backspace.frame.contains(point) {
            let localPoint = convert(point, to: backspace)
            return backspace.hitTest(localPoint, with: event) ?? backspace
        }
        return super.hitTest(point, with: event)
    }

    // MARK: - Popup helpers
    private func showPopup(for key: KeyButton) {
        hideKeyPreview()
        cancelPopup()
        let chars = key.definition.holdCharacters
        guard !chars.isEmpty else { return }

        let popup = PopupKeyView(theme: theme)
        popup.configure(holdCharacters: chars)
        popup.onSelectCharacter = { [weak self, weak key] resolved in
            guard let self = self, let key = key else { return }
            self.delegate?.keyboardView(self, didHold: key.definition, resolved: resolved)
            self.cancelPopup()
        }

        // Keep alternates in the extension's root view. iOS clips custom
        // keyboards at that boundary even when a subview is added to `window`.
        let targetParent: UIView = superview ?? self
        popup.translatesAutoresizingMaskIntoConstraints = false
        targetParent.addSubview(popup)

        let topCount = chars.filter { $0.first?.isLetter == true }.count
        let bottomCount = chars.count - topCount
        let hasTop = topCount > 0
        let hasBottom = bottomCount > 0
        let isTwoRows = hasTop && hasBottom

        let popupHeight: CGFloat = isTwoRows ? 125 : 67
        let colCount = max(1, max(topCount, bottomCount))
        let popupWidth: CGFloat = min(targetParent.bounds.width - 8,
                                      CGFloat(colCount) * 40 + CGFloat(max(0, colCount - 1)) * 3 + 12)

        // Convert key frame to targetParent coordinates
        let keyFrameInTarget = key.convert(key.bounds, to: targetParent)

        let proposedAboveY = keyFrameInTarget.minY - popupHeight - 8
        let popupY: CGFloat
        if proposedAboveY >= 4 {
            popupY = proposedAboveY
        } else {
            // A third-party keyboard cannot draw outside its host view. Keep
            // the entire tall panel visible at the top of that view instead.
            popupY = 4
        }

        var frame = CGRect(x: keyFrameInTarget.midX - popupWidth / 2,
                           y: popupY,
                           width: popupWidth, height: popupHeight)

        if frame.minX < 4 { frame.origin.x = 4 }
        if frame.maxX > targetParent.bounds.width - 4 { frame.origin.x = targetParent.bounds.width - 4 - frame.width }

        popup.translatesAutoresizingMaskIntoConstraints = true
        popup.frame = frame
        self.popup = popup
        self.popupOwner = key
        HapticManager.shared.special()
    }

    func cancelPopup() {
        popup?.removeFromSuperview()
        popup = nil
        popupOwner = nil
    }

    private func showKeyPreview(for key: KeyButton) {
        hideKeyPreview()
        guard SharedDefaults.bool(SharedDefaults.Key.charPreviewEnabled, default: true),
              key.definition.type == .letter,
              !key.displayString.isEmpty else { return }

        let targetParent: UIView = superview ?? self
        let keyFrame = key.convert(key.bounds, to: targetParent)
        let previewWidth = max(52, keyFrame.width + 18)
        let capHeight = max(52, keyFrame.height * 1.2)
        let previewTop = max(2, keyFrame.minY - capHeight)
        // The narrow stem occupies the pressed key itself. Previously the
        // preview extended almost a full row below the key, making J appear to
        // originate near B/N instead of directly above J.
        let previewBottom = keyFrame.maxY
        var previewX = keyFrame.midX - previewWidth / 2
        previewX = max(3, min(previewX, targetParent.bounds.width - previewWidth - 3))

        let preview = KeyPreviewView(text: key.displayString,
                                     theme: theme,
                                     stemWidth: keyFrame.width,
                                     stemCenterX: keyFrame.midX - previewX,
                                     shoulderY: keyFrame.minY - previewTop - 9)
        preview.frame = CGRect(x: previewX, y: previewTop,
                               width: previewWidth, height: previewBottom - previewTop)
        targetParent.addSubview(preview)
        keyPreview = preview
    }

    private func hideKeyPreview() {
        keyPreview?.removeFromSuperview()
        keyPreview = nil
    }

    // MARK: - Backspace repeat
    private func startBackspaceRepeat() {
        stopBackspaceRepeat()
        let speed = max(0.02, SharedDefaults.double(SharedDefaults.Key.backspaceSpeedMs, default: 80) / 1000.0)
        let initial = Timer(timeInterval: 0.35, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            let repeating = Timer(timeInterval: speed, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.delegate?.keyboardViewBackspaceRepeat(self)
            }
            RunLoop.main.add(repeating, forMode: .common)
            self.backspaceTimer = repeating
        }
        RunLoop.main.add(initial, forMode: .common)
        backspaceTimer = initial
    }

    private func stopBackspaceRepeat() {
        backspaceTimer?.invalidate()
        backspaceTimer = nil
    }

    private func letterKey(at point: CGPoint) -> KeyButton? {
        guard currentPage == .letters else { return nil }
        return rows.joined().first {
            $0.definition.type == .letter && $0.frame.insetBy(dx: -3, dy: -3).contains(point)
        }
    }

    private func appendGlideKeys(from start: CGPoint, to end: CGPoint) {
        let distance = hypot(end.x - start.x, end.y - start.y)
        let steps = max(1, Int(ceil(distance / 8)))
        for step in 1...steps {
            let amount = CGFloat(step) / CGFloat(steps)
            let point = CGPoint(x: start.x + (end.x - start.x) * amount,
                                y: start.y + (end.y - start.y) * amount)
            guard let key = letterKey(at: point) else { continue }
            let value = key.definition.primary.lowercased()
            if glideTrace.last != value { glideTrace.append(value) }
        }
    }

    private func updateGlideTrail(with point: CGPoint) {
        glidePoints.append(point)
        let path = UIBezierPath()
        if let first = glidePoints.first {
            path.move(to: first)
            for point in glidePoints.dropFirst() { path.addLine(to: point) }
        }
        glideLayer.path = path.cgPath
    }

    private func finishGlideTrail() {
        guard glideLayer.superlayer != nil else { return }
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            self?.glideLayer.removeFromSuperlayer()
            self?.glideLayer.opacity = 1
            self?.glideLayer.path = nil
        }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.18
        glideLayer.opacity = 0
        glideLayer.add(fade, forKey: "fade")
        CATransaction.commit()
        glidePoints.removeAll()
    }
}

// MARK: - KeyButtonDelegate

extension KeyboardView: KeyButtonDelegate {
    func keyButton(_ button: KeyButton, didBegin touch: UITouch) {
        holdTimer?.invalidate()
        spaceHoldTimer?.invalidate()
        spaceHoldTimer = nil
        spaceCursorMode = false
        touchStart = touch.location(in: self)
        touchStartTimestamp = touch.timestamp
        lastTouchPoint = touchStart
        glideDistance = 0
        glideActivated = false
        glideTrace = []
        glidePoints = []
        backspaceSwipeWords = 0

        // If a popup is open from another key, cancel it
        if popup != nil, popupOwner !== button {
            cancelPopup()
        }

        if button.definition.type == .backspace {
            // Delete on touch-down, like the system keyboard, so a quick tap is
            // never mistaken for a hold that did not fire.
            delegate?.keyboardView(self, didTap: button.definition)
            startBackspaceRepeat()
            return
        }

        showKeyPreview(for: button)

        if currentPage == .letters, button.definition.type == .letter {
            glideTrace = [button.definition.primary.lowercased()]
        }
        if button.definition.type == .nextKeyboard {
            delegate?.keyboardViewNextKeyboardEvent(self, sender: button, event: nil)
            return
        }

        if button.definition.type == .space {
            // Long-press on space enters iOS-style cursor-drag mode: after a
            // short hold, horizontal finger motion moves the caret instead of
            // inserting a space on lift.
            spaceCursorLastX = touchStart.x
            let t = Timer(timeInterval: max(0.28, holdThreshold), repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.spaceCursorMode = true
                self.delegate?.keyboardViewSpaceCursorBegan(self)
                HapticManager.shared.special()
            }
            RunLoop.main.add(t, forMode: .common)
            spaceHoldTimer = t
        }

        if !button.definition.holdCharacters.isEmpty {
            // Schedule on .common modes so the timer fires uniformly across all
            // keys — otherwise edge keys need a much longer hold because the
            // runloop stays in .tracking mode during finger micro-motion and
            // .default-mode timers never fire until touchesEnded.
            let t = Timer(timeInterval: holdThreshold, repeats: false) { [weak self, weak button] _ in
                guard let self = self, let button = button else { return }
                self.showPopup(for: button)
            }
            RunLoop.main.add(t, forMode: .common)
            holdTimer = t
        }
    }

    func keyButton(_ button: KeyButton, didMove touch: UITouch) {
        let point = touch.location(in: self)
        let segmentDistance = hypot(point.x - lastTouchPoint.x, point.y - lastTouchPoint.y)
        glideDistance += segmentDistance

        if glideDistance > 6 {
            hideKeyPreview()
        }

        // Hold-space cursor drag: while the mode is active, translate horizontal
        // finger motion into character offsets and eat the event so it isn't
        // also interpreted as anything else.
        if button.definition.type == .space, spaceCursorMode {
            let dx = point.x - spaceCursorLastX
            let step = KeyboardView.spaceCursorPointsPerChar
            let n = Int((dx / step).rounded(.towardZero))
            if n != 0 {
                delegate?.keyboardViewSpaceCursorMove(self, characterOffset: n)
                spaceCursorLastX += CGFloat(n) * step
            }
            lastTouchPoint = point
            return
        }

        if button.definition.type == .backspace {
            let dx = point.x - touchStart.x
            if dx < -14 {
                stopBackspaceRepeat()
                backspaceSwipeWords = max(1, Int(abs(dx) / 36))
            }
            lastTouchPoint = point
            return
        }

        if let popup = popup, popupOwner === button {
            let p = touch.location(in: popup)
            popup.highlightCharacter(at: p)
            lastTouchPoint = point
            return
        }

        let elapsedMs = (touch.timestamp - touchStartTimestamp) * 1000
        let triggerMs = SharedDefaults.double(SharedDefaults.Key.glideTriggerMs, default: 80)
        if !glideTrace.isEmpty, glideDistance > 10, elapsedMs >= triggerMs {
            holdTimer?.invalidate()
            holdTimer = nil
            if !glideActivated {
                glideActivated = true
                layer.addSublayer(glideLayer)
                updateGlideTrail(with: touchStart)
                appendGlideKeys(from: touchStart, to: point)
            } else {
                appendGlideKeys(from: lastTouchPoint, to: point)
            }
            updateGlideTrail(with: point)
        }
        lastTouchPoint = point
    }

    func keyButton(_ button: KeyButton, didEnd touch: UITouch, cancelled: Bool) {
        holdTimer?.invalidate()
        holdTimer = nil
        hideKeyPreview()

        // End any active space cursor drag. If we were in cursor mode, do NOT
        // fall through to the tap path — the user was moving the caret, not
        // inserting a space.
        if button.definition.type == .space {
            spaceHoldTimer?.invalidate()
            spaceHoldTimer = nil
            if spaceCursorMode {
                spaceCursorMode = false
                delegate?.keyboardViewSpaceCursorEnded(self)
                return
            }
        }

        if button.definition.type == .backspace {
            stopBackspaceRepeat()
            if !cancelled, backspaceSwipeWords > 0 {
                delegate?.keyboardView(self, deleteWords: backspaceSwipeWords)
            }
            backspaceSwipeWords = 0
            return
        }

        if let popup = popup, popupOwner === button {
            finishGlideTrail()
            if !cancelled {
                // Resolve once more at the lift location so releasing over an
                // alternate always selects that character, even if UIKit did
                // not deliver a final touchesMoved event.
                popup.highlightCharacter(at: touch.location(in: popup))
                if let ch = popup.selectedCharacter {
                    delegate?.keyboardView(self, didHold: button.definition, resolved: ch)
                }
                cancelPopup()
                return
            }
            cancelPopup()
            return
        }

        if !cancelled, glideActivated, glideDistance > 18, glideTrace.count >= 2 {
            delegate?.keyboardView(self, didGlide: glideTrace)
            glideTrace = []
            finishGlideTrail()
            return
        }

        finishGlideTrail()

        if !cancelled {
            // Dismiss active popup if tapping another key
            cancelPopup()
            delegate?.keyboardView(self, didTap: button.definition)
        }
    }
}

private final class KeyPreviewView: UIView {
    private let label = UILabel()
    private let shape = CAShapeLayer()
    private let stemWidth: CGFloat
    private let stemCenterX: CGFloat
    private let shoulderY: CGFloat

    init(text: String, theme: KeyboardTheme, stemWidth: CGFloat,
         stemCenterX: CGFloat, shoulderY: CGFloat) {
        self.stemWidth = stemWidth
        self.stemCenterX = stemCenterX
        self.shoulderY = shoulderY
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.32
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 3)

        shape.fillColor = theme.keyBackground.cgColor
        shape.strokeColor = theme.keyTextColor.withAlphaComponent(0.18).cgColor
        shape.lineWidth = 1
        layer.addSublayer(shape)

        label.text = text
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 31, weight: .regular)
        label.textColor = theme.keyTextColor
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let capCorner: CGFloat = 13
        let stemCorner: CGFloat = 10
        let stemLeft = max(0, stemCenterX - stemWidth / 2)
        let stemRight = min(bounds.width, stemCenterX + stemWidth / 2)
        let shoulder = min(max(capCorner * 2, shoulderY), bounds.height - stemCorner - 8)
        let neck = min(bounds.height - stemCorner - 3, shoulder + 17)

        let path = UIBezierPath()
        path.move(to: CGPoint(x: capCorner, y: 0))
        path.addLine(to: CGPoint(x: bounds.width - capCorner, y: 0))
        path.addQuadCurve(to: CGPoint(x: bounds.width, y: capCorner),
                          controlPoint: CGPoint(x: bounds.width, y: 0))
        path.addLine(to: CGPoint(x: bounds.width, y: shoulder - 8))
        path.addCurve(to: CGPoint(x: stemRight, y: neck),
                      controlPoint1: CGPoint(x: bounds.width, y: shoulder + 3),
                      controlPoint2: CGPoint(x: stemRight, y: shoulder + 3))
        path.addLine(to: CGPoint(x: stemRight, y: bounds.height - stemCorner))
        path.addQuadCurve(to: CGPoint(x: stemRight - stemCorner, y: bounds.height),
                          controlPoint: CGPoint(x: stemRight, y: bounds.height))
        path.addLine(to: CGPoint(x: stemLeft + stemCorner, y: bounds.height))
        path.addQuadCurve(to: CGPoint(x: stemLeft, y: bounds.height - stemCorner),
                          controlPoint: CGPoint(x: stemLeft, y: bounds.height))
        path.addLine(to: CGPoint(x: stemLeft, y: neck))
        path.addCurve(to: CGPoint(x: 0, y: shoulder - 8),
                      controlPoint1: CGPoint(x: stemLeft, y: shoulder + 3),
                      controlPoint2: CGPoint(x: 0, y: shoulder + 3))
        path.addLine(to: CGPoint(x: 0, y: capCorner))
        path.addQuadCurve(to: CGPoint(x: capCorner, y: 0),
                          controlPoint: CGPoint(x: 0, y: 0))
        path.close()

        shape.frame = bounds
        shape.path = path.cgPath
        layer.shadowPath = path.cgPath
        label.frame = CGRect(x: 0, y: 2, width: bounds.width, height: max(38, shoulder - 5))
    }
}
