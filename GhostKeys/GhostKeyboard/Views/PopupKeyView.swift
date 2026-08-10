import UIKit

/// Long-press popup showing alternate characters horizontally.
final class PopupKeyView: UIView {
    private let stack = UIStackView()
    private var labels: [UILabel] = []
    private(set) var characters: [String] = []
    private(set) var highlightedIndex: Int = 0
    private var theme: KeyboardTheme

    init(theme: KeyboardTheme) {
        self.theme = theme
        super.init(frame: .zero)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = theme.popupBackground
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)

        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func configure(characters: [String]) {
        self.characters = characters
        labels.forEach { $0.removeFromSuperview() }
        labels.removeAll()
        for ch in characters {
            let l = UILabel()
            l.text = ch
            l.font = .systemFont(ofSize: 21, weight: .regular)
            l.textAlignment = .center
            l.textColor = theme.keyTextColor
            l.backgroundColor = .clear
            l.layer.cornerRadius = 6
            l.layer.masksToBounds = true
            l.translatesAutoresizingMaskIntoConstraints = false
            l.widthAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true
            stack.addArrangedSubview(l)
            labels.append(l)
        }
        highlightedIndex = 0
        updateHighlight()
    }

    func highlightIndex(forXInSelf x: CGFloat) {
        guard !labels.isEmpty else { return }
        let width = bounds.width
        guard width > 0 else { return }
        let idx = max(0, min(labels.count - 1, Int(x / (width / CGFloat(labels.count)))))
        if idx != highlightedIndex {
            highlightedIndex = idx
            updateHighlight()
            HapticManager.shared.tap()
        }
    }

    var selectedCharacter: String? {
        guard highlightedIndex >= 0, highlightedIndex < characters.count else { return nil }
        return characters[highlightedIndex]
    }

    private func updateHighlight() {
        for (i, l) in labels.enumerated() {
            if i == highlightedIndex {
                l.backgroundColor = theme.popupHighlight
                l.textColor = .white
            } else {
                l.backgroundColor = .clear
                l.textColor = theme.keyTextColor
            }
        }
    }
}
