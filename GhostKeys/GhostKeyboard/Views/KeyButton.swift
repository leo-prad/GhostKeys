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
    private var theme: KeyboardTheme
    private var isHighlighted = false { didSet { applyBackground() } }

    /// Displayed label for the current shift state.
    var displayString: String = "" {
        didSet { label.text = displayString }
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
        layer.cornerRadius = 8
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
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        applyBackground()
    }

    func apply(theme: KeyboardTheme) {
        self.theme = theme
        label.textColor = theme.keyTextColor
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
