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
        // Trailing alignment makes a short number/symbol row hug the popup's
        // right edge, matching the reference layout.
        containerStack.alignment = .trailing
        containerStack.distribution = .fill
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        containerStack.isLayoutMarginsRelativeArrangement = true
        containerStack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
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

        let accentLetters = holdCharacters.filter { $0.first?.isLetter == true }
        let symbols = holdCharacters.filter { $0.first?.isLetter != true }

        var sequence: [String] = []

        // Accent letters (e.g. è, é, ê, ë, ē) go on top row
        for ch in accentLetters {
            let l = createLabel(text: ch)
            topStack.addArrangedSubview(l)
            labelViews.append(l)
            sequence.append(ch)
        }

        // All number/symbol alternatives share the bottom row. This matters on
        // the symbol pages where a key can expose several currency or quote marks.
        for ch in symbols {
            let l = createLabel(text: ch)
            bottomStack.addArrangedSubview(l)
            labelViews.append(l)
            sequence.append(ch)
        }

        self.characterSequence = sequence
        topStack.isHidden = accentLetters.isEmpty
        bottomStack.isHidden = symbols.isEmpty

        highlightedIndex = symbols.isEmpty ? 0 : accentLetters.count
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
        NSLayoutConstraint.activate([
            l.widthAnchor.constraint(equalToConstant: 40),
            l.heightAnchor.constraint(equalToConstant: 78)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(labelTapped(_:)))
        l.addGestureRecognizer(tap)
        return l
    }

    @objc private func labelTapped(_ sender: UITapGestureRecognizer) {
        guard let l = sender.view as? UILabel, let text = l.text else { return }
        onSelectCharacter?(text)
    }

    /// Highlights the alternate nearest to the finger. Using both axes is
    /// important because number/symbol alternates live below accent letters.
    func highlightCharacter(at point: CGPoint) {
        guard !labelViews.isEmpty else { return }
        layoutIfNeeded()

        let idx = labelViews.enumerated().min { lhs, rhs in
            let lhsCenter = lhs.element.convert(lhs.element.bounds, to: self).center
            let rhsCenter = rhs.element.convert(rhs.element.bounds, to: self).center
            return lhsCenter.distanceSquared(to: point) < rhsCenter.distanceSquared(to: point)
        }?.offset ?? highlightedIndex

        if idx != highlightedIndex {
            highlightedIndex = idx
            updateHighlight()
            HapticManager.shared.specialSelection()
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

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

private extension CGPoint {
    func distanceSquared(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return dx * dx + dy * dy
    }
}
