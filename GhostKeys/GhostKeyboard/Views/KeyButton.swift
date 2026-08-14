import UIKit

protocol KeyButtonDelegate: AnyObject {
    func keyButton(_ button: KeyButton, didBegin touch: UITouch)
    func keyButton(_ button: KeyButton, didMove touch: UITouch)
    func keyButton(_ button: KeyButton, didEnd touch: UITouch, cancelled: Bool)
}

final class KeyButton: UIView {
    let definition: KeyDefinition
    weak var delegate: KeyButtonDelegate?

    let label = UILabel()
    let hintLabel = UILabel()
    let iconImageView = UIImageView()

    private var theme: KeyboardTheme
    private var isHighlighted = false {
        didSet {
            applyBackground()
            if definition.type == .backspace { updateContent() }
        }
    }

    /// Displayed label for the current shift state.
    var displayString: String = "" {
        didSet {
            updateContent()
        }
    }

    init(definition: KeyDefinition, theme: KeyboardTheme) {
        self.definition = definition
        self.theme = theme
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        isMultipleTouchEnabled = false
        layer.cornerRadius = 10
        layer.cornerCurve = .continuous
        layer.shadowColor = theme.keyShadowColor.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0
        layer.shadowOpacity = 1.0

        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = theme.keyTextColor
        label.font = fontForKey()
        label.text = definition.primary
        addSubview(label)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .center
        iconImageView.tintColor = theme.keyTextColor
        addSubview(iconImageView)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        // Top-right secondary character hint label (e.g., '1' on 'q', '3' on 'e', '@' on 'a')
        if definition.type == .letter, let firstHold = definition.holdCharacters.first {
            hintLabel.translatesAutoresizingMaskIntoConstraints = true
            hintLabel.textAlignment = .right
            hintLabel.font = .systemFont(ofSize: 11, weight: .regular)
            hintLabel.textColor = theme.keyTextColor.withAlphaComponent(0.45)
            hintLabel.text = firstHold
            hintLabel.numberOfLines = 1
            hintLabel.adjustsFontSizeToFitWidth = false
            addSubview(hintLabel)
        }

        updateContent()
        applyBackground()
    }

    private func updateContent() {
        switch definition.type {
        case .shift:
            label.isHidden = true
            iconImageView.isHidden = false
            let name: String
            let weight: UIImage.SymbolWeight
            switch displayString {
            case "⇪": name = "capslock.fill"; weight = .semibold
            case "⇧": name = "shift.fill";    weight = .semibold
            default:  name = "shift";          weight = .regular
            }
            let config = UIImage.SymbolConfiguration(pointSize: 19, weight: weight)
            iconImageView.image = UIImage(systemName: name, withConfiguration: config)
        case .backspace:
            label.isHidden = true
            iconImageView.isHidden = false
            let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
            let name = isHighlighted ? "delete.left.fill" : "delete.left"
            iconImageView.image = UIImage(systemName: name, withConfiguration: config)
        default:
            label.isHidden = false
            iconImageView.isHidden = true
            label.text = displayString
        }
    }

    func apply(theme: KeyboardTheme) {
        self.theme = theme
        label.textColor = theme.keyTextColor
        hintLabel.textColor = theme.keyTextColor.withAlphaComponent(0.45)
        iconImageView.tintColor = theme.keyTextColor
        layer.shadowColor = theme.keyShadowColor.cgColor
        applyBackground()
    }

    private func fontForKey() -> UIFont {
        switch definition.type {
        case .letter:
            return .systemFont(ofSize: 22, weight: .regular)
        case .space:
            return .systemFont(ofSize: 15, weight: .regular)
        default:
            return .systemFont(ofSize: 16, weight: .regular)
        }
    }

    private func applyBackground() {
        let base: UIColor
        switch definition.type {
        case .letter:
            base = theme.keyBackground
        default:
            base = theme.specialKeyBackground
        }
        backgroundColor = isHighlighted ? theme.keyHighlightColor : base
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !hintLabel.isHidden, hintLabel.text != nil else { return }
        let size = hintLabel.sizeThatFits(CGSize(width: bounds.width - 8, height: 16))
        let width = max(16, ceil(size.width))
        // Pin the natural-size glyph box to the top-right. Avoiding a short
        // fixed-height Auto Layout box prevents vertical glyph compression.
        hintLabel.frame = CGRect(x: bounds.width - width - 4, y: 1,
                                 width: width, height: 16)
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if definition.type == .backspace {
            return bounds.insetBy(dx: -10, dy: -6).contains(point)
        }
        // KeyboardView.hitTest picked this key by nearest-midX / nearest-row
        // routing. The routed localPoint often sits outside our own bounds
        // (that is the whole point — gap taps land here). Accept everything so
        // iOS does not drop the touch during delivery.
        return true
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        isHighlighted = true
        delegate?.keyButton(self, didBegin: t)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        delegate?.keyButton(self, didMove: t)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        isHighlighted = false
        delegate?.keyButton(self, didEnd: t, cancelled: false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        isHighlighted = false
        delegate?.keyButton(self, didEnd: t, cancelled: true)
    }
}
