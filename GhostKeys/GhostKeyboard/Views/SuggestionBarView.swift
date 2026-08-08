import UIKit

protocol SuggestionBarDelegate: AnyObject {
    func suggestionBar(_ bar: SuggestionBarView, didSelect suggestion: String, isAutocorrect: Bool)
}

final class SuggestionBarView: UIView {
    weak var delegate: SuggestionBarDelegate?
    private let stack = UIStackView()
    private var buttons: [UIButton] = []
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
            let b = UIButton(type: .system)
            b.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
            b.setTitleColor(theme.keyTextColor, for: .normal)
            b.tag = i
            b.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            stack.addArrangedSubview(b)
            buttons.append(b)

            if i < 2 {
                let sep = UIView()
                sep.backgroundColor = theme.keyTextColor.withAlphaComponent(0.15)
                sep.translatesAutoresizingMaskIntoConstraints = false
                addSubview(sep)
                NSLayoutConstraint.activate([
                    sep.widthAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),
                    sep.topAnchor.constraint(equalTo: topAnchor, constant: 8),
                    sep.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
                    sep.leadingAnchor.constraint(equalTo: b.trailingAnchor)
                ])
            }
        }
    }

    func apply(theme: KeyboardTheme) {
        self.theme = theme
        backgroundColor = theme.suggestionBarBackground
        for b in buttons { b.setTitleColor(theme.keyTextColor, for: .normal) }
        render()
    }

    func setSuggestions(_ list: [String], autocorrectIndex: Int? = nil) {
        self.suggestions = list
        self.autocorrectIndex = autocorrectIndex
        render()
    }

    private func render() {
        for (i, b) in buttons.enumerated() {
            let s = i < suggestions.count ? suggestions[i] : ""
            let isAuto = (i == autocorrectIndex)
            if isAuto {
                b.setAttributedTitle(NSAttributedString(string: "“\(s)”", attributes: [
                    .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                    .foregroundColor: theme.keyTextColor
                ]), for: .normal)
            } else {
                b.setAttributedTitle(NSAttributedString(string: s, attributes: [
                    .font: UIFont.systemFont(ofSize: 17, weight: .regular),
                    .foregroundColor: theme.keyTextColor
                ]), for: .normal)
            }
        }
    }

    @objc private func tapped(_ sender: UIButton) {
        let idx = sender.tag
        guard idx < suggestions.count, !suggestions[idx].isEmpty else { return }
        let isAuto = (idx == autocorrectIndex)
        delegate?.suggestionBar(self, didSelect: suggestions[idx], isAutocorrect: isAuto)
    }
}
