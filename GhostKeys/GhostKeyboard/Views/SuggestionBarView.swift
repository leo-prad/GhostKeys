import UIKit

protocol SuggestionBarDelegate: AnyObject {
    func suggestionBar(_ bar: SuggestionBarView, didSelect suggestion: String, isAutocorrect: Bool)
}

final class SuggestionItemView: UIView {
    private let highlightView = UIView()
    private let label = UILabel()
    private var isHighlighted = false {
        didSet {
            highlightView.isHidden = !isHighlighted
        }
    }

    var text: String = ""
    var isAutocorrect: Bool = false
    var itemIndex: Int = 0
    var onSelect: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        isUserInteractionEnabled = true
        highlightView.isUserInteractionEnabled = false
        highlightView.isHidden = true
        highlightView.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        highlightView.layer.cornerRadius = 15
        highlightView.layer.cornerCurve = .continuous
        highlightView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(highlightView)

        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            // SF Pro's visual center sits slightly below its geometric line
            // box. Lift it enough to look centered in the full suggestion area.
            label.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -5),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),

            highlightView.leadingAnchor.constraint(equalTo: label.leadingAnchor, constant: -12),
            highlightView.trailingAnchor.constraint(equalTo: label.trailingAnchor, constant: 12),
            highlightView.centerYAnchor.constraint(equalTo: label.centerYAnchor),
            highlightView.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    func configure(text: String, isAutocorrect: Bool, textColor: UIColor) {
        isHighlighted = false
        self.text = text
        self.isAutocorrect = isAutocorrect
        if isAutocorrect {
            label.attributedText = NSAttributedString(string: "“\(text)”", attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: textColor
            ])
        } else {
            label.attributedText = NSAttributedString(string: text, attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .regular),
                .foregroundColor: textColor
            ])
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isHighlighted = true
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isHighlighted = false
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        if bounds.contains(loc) && !text.isEmpty {
            onSelect?(itemIndex)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isHighlighted = false
    }
}

final class SuggestionBarView: UIView {
    weak var delegate: SuggestionBarDelegate?
    private let stack = UIStackView()
    private var itemViews: [SuggestionItemView] = []
    private var suggestions: [String] = []
    private var autocorrectIndex: Int? = nil
    private var theme: KeyboardTheme

    init(theme: KeyboardTheme) {
        self.theme = theme
        super.init(frame: .zero)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        clipsToBounds = false
        backgroundColor = theme.suggestionBarBackground
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 0
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        for i in 0..<3 {
            let item = SuggestionItemView()
            item.itemIndex = i
            item.onSelect = { [weak self] index in
                self?.handleSelection(at: index)
            }
            stack.addArrangedSubview(item)
            itemViews.append(item)

            if i < 2 {
                let sep = UIView()
                sep.isUserInteractionEnabled = false
                sep.backgroundColor = theme.keyTextColor.withAlphaComponent(0.35)
                sep.translatesAutoresizingMaskIntoConstraints = false
                addSubview(sep)
                NSLayoutConstraint.activate([
                    sep.widthAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),
                    sep.centerYAnchor.constraint(equalTo: centerYAnchor),
                    sep.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.55),
                    sep.leadingAnchor.constraint(equalTo: item.trailingAnchor)
                ])
            }
        }
    }

    func apply(theme: KeyboardTheme) {
        self.theme = theme
        backgroundColor = theme.suggestionBarBackground
        render()
    }

    func setSuggestions(_ list: [String], autocorrectIndex: Int? = nil) {
        self.suggestions = list
        self.autocorrectIndex = autocorrectIndex
        render()
    }

    private func render() {
        for (i, item) in itemViews.enumerated() {
            let s = i < suggestions.count ? suggestions[i] : ""
            let isAuto = (i == autocorrectIndex)
            item.configure(text: s, isAutocorrect: isAuto, textColor: theme.keyTextColor)
        }
    }

    private func handleSelection(at index: Int) {
        guard index < suggestions.count, !suggestions[index].isEmpty else { return }
        let isAuto = (index == autocorrectIndex)
        delegate?.suggestionBar(self, didSelect: suggestions[index], isAutocorrect: isAuto)
    }
}
