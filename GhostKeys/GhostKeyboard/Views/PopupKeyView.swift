import UIKit

/// Long-press popup showing alternate characters in a 2-row stacked layout (accents on top, symbol/number on bottom with blue badge), matching ghostkeys-simulator.html.
final class PopupKeyView: UIView {
    private let containerStack = UIStackView()
    private let topStack = UIStackView()
    private let bottomStack = UIStackView()

    private var labelViews: [UILabel] = []
    private(set) var characterSequence: [String] = []
    private(set) var highlightedIndex: Int = 0
    private var theme: KeyboardTheme

    var onSelectCharacter: ((String) -> Void)?

    init(theme: KeyboardTheme) {
        self.theme = theme
        super.init(frame: .zero)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        isUserInteractionEnabled = true
        backgroundColor = theme.popupBackground
        layer.cornerRadius = 10
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.40
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 4)

        containerStack.axis = .vertical
        containerStack.spacing = 3
        containerStack.alignment = .center
        containerStack.distribution = .fill
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        containerStack.isLayoutMarginsRelativeArrangement = true
        containerStack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
        addSubview(containerStack)

        topStack.axis = .horizontal
        topStack.spacing = 3
        topStack.alignment = .fill
        topStack.distribution = .fillEqually

        bottomStack.axis = .horizontal
        bottomStack.spacing = 3
        bottomStack.alignment = .fill
        bottomStack.distribution = .fillEqually

        containerStack.addArrangedSubview(topStack)
        containerStack.addArrangedSubview(bottomStack)

        NSLayoutConstraint.activate([
            containerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerStack.topAnchor.constraint(equalTo: topAnchor),
            containerStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func configure(holdCharacters: [String]) {
        labelViews.forEach { $0.removeFromSuperview() }
        labelViews.removeAll()
        topStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        bottomStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        var primaryHold: String? = nil
        var accentLetters: [String] = []

        for ch in holdCharacters {
            if primaryHold == nil, let f = ch.first, f.isNumber || "!@#$%^&*()-_=+[]{}|;:'\",.<>/?~".contains(f) {
                primaryHold = ch
            } else {
                accentLetters.append(ch)
            }
        }

        var sequence: [String] = []

        // If there's a primary number/symbol (e.g. '3' or '@'), place it on the bottom row
        if let primary = primaryHold {
            let l = createLabel(text: primary)
            bottomStack.addArrangedSubview(l)
            labelViews.append(l)
            sequence.append(primary)
        }

        // Accent letters (e.g. è, é, ê, ë, ē) go on top row
        for ch in accentLetters {
            let l = createLabel(text: ch)
            topStack.addArrangedSubview(l)
            labelViews.append(l)
            sequence.append(ch)
        }

        self.characterSequence = sequence
        topStack.isHidden = accentLetters.isEmpty
        bottomStack.isHidden = (primaryHold == nil)

        highlightedIndex = 0
        updateHighlight()
    }

    private func createLabel(text: String) -> UILabel {
        let l = UILabel()
        l.isUserInteractionEnabled = true
        l.text = text
        l.font = .systemFont(ofSize: 20, weight: .regular)
        l.textAlignment = .center
        l.textColor = theme.keyTextColor
        l.backgroundColor = .clear
        l.layer.cornerRadius = 6
        l.layer.masksToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        l.widthAnchor.constraint(greaterThanOrEqualToConstant: 34).isActive = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(labelTapped(_:)))
        l.addGestureRecognizer(tap)
        return l
    }

    @objc private func labelTapped(_ sender: UITapGestureRecognizer) {
        guard let l = sender.view as? UILabel, let text = l.text else { return }
        onSelectCharacter?(text)
    }

    func highlightIndex(forXInSelf x: CGFloat) {
        guard !labelViews.isEmpty else { return }
        let width = bounds.width
        guard width > 0 else { return }
        let idx = max(0, min(labelViews.count - 1, Int(x / (width / CGFloat(labelViews.count)))))
        if idx != highlightedIndex {
            highlightedIndex = idx
            updateHighlight()
            HapticManager.shared.tap()
        }
    }

    var selectedCharacter: String? {
        guard highlightedIndex >= 0, highlightedIndex < characterSequence.count else { return nil }
        return characterSequence[highlightedIndex]
    }

    private func updateHighlight() {
        for (i, l) in labelViews.enumerated() {
            if i == highlightedIndex {
                l.backgroundColor = theme.accentBlue
                l.textColor = .white
            } else {
                l.backgroundColor = .clear
                l.textColor = theme.keyTextColor
            }
        }
    }
}
