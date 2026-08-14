import UIKit

protocol KeyButtonDelegate: AnyObject {
    func keyButton(_ button: KeyButton, didBegin touch: UITouch)
    func keyButton(_ button: KeyButton, didMove touch: UITouch)
    func keyButton(_ button: KeyButton, didEnd touch: UITouch, cancelled: Bool)
}

/// A key on the keyboard.
///
/// The view's own frame is the *touch tile* — KeyboardView sizes it to fill
/// its share of the keyboard with no gaps between neighbors, so every point in
/// the keyboard belongs to exactly one key (there are no dead zones between or
/// beside keys). The visible rounded keycap is drawn by `capView`, inset within
/// the tile, which reproduces the spaced-out look. This mirrors how the system
/// keyboard separates a key's hit area from its drawn cap.
final class KeyButton: UIView {
    let definition: KeyDefinition
    weak var delegate: KeyButtonDelegate?

    /// The drawn keycap. `KeyButton` itself is transparent and only defines the
    /// touch tile; everything visible lives on this inset subview.
    private let capView = UIView()

    let label = UILabel()
    let hintLabel = UILabel()
    let iconImageView = UIImageView()

    private var theme: KeyboardTheme

    /// Frame of the visible keycap, in this view's own coordinate space. Set by
    /// KeyboardView during layout; the tile frame (self.frame) is larger and
    /// fills the gaps around it.
    var capRect: CGRect = .zero {
        didSet {
            guard capRect != oldValue else { return }
            setNeedsLayout()
        }
    }

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
        backgroundColor = .clear

        // The cap carries all the visible styling. It must not intercept
        // touches itself — the touch tile (self) handles them — so hit-testing
        // resolves to KeyButton and its delegate fires.
        capView.isUserInteractionEnabled = false
        capView.layer.cornerRadius = 10
        capView.layer.cornerCurve = .continuous
        capView.layer.shadowColor = theme.keyShadowColor.cgColor
        capView.layer.shadowOffset = CGSize(width: 0, height: 1)
        capView.layer.shadowRadius = 0
        capView.layer.shadowOpacity = 1.0
        addSubview(capView)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = theme.keyTextColor
        label.font = fontForKey()
        label.text = definition.primary
        capView.addSubview(label)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .center
        iconImageView.tintColor = theme.keyTextColor
        capView.addSubview(iconImageView)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: capView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: capView.centerYAnchor),
            iconImageView.centerXAnchor.constraint(equalTo: capView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: capView.centerYAnchor)
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
            capView.addSubview(hintLabel)
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
        capView.layer.shadowColor = theme.keyShadowColor.cgColor
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
        capView.backgroundColor = isHighlighted ? theme.keyHighlightColor : base
    }

    /// The visible keycap frame in another view's coordinate space — used to
    /// anchor popups and key previews to the drawn cap rather than the (larger)
    /// touch tile.
    func capFrame(in view: UIView) -> CGRect {
        return convert(capView.frame, to: view)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        capView.frame = capRect == .zero ? bounds : capRect

        guard !hintLabel.isHidden, hintLabel.text != nil else { return }
        let size = hintLabel.sizeThatFits(CGSize(width: capView.bounds.width - 8, height: 16))
        let width = max(16, ceil(size.width))
        // Pin the natural-size glyph box to the top-right of the cap. Avoiding a
        // short fixed-height Auto Layout box prevents vertical glyph compression.
        hintLabel.frame = CGRect(x: capView.bounds.width - width - 4, y: 1,
                                 width: width, height: 16)
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
