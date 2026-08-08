import UIKit

final class KeyboardViewController: UIInputViewController {
    private let state = KeyboardState()
    private lazy var engine = PredictionEngine()
    private var keyboardView: KeyboardView!
    private var suggestionBar: SuggestionBarView!
    private var heightConstraint: NSLayoutConstraint!
    private var lastShiftTap: Date?
    private var lastCommittedWord: String? // for revert-after-autocorrect
    private var pendingAutocorrectTyped: String? // the typo that was replaced
    private var pendingAutocorrectCorrected: String?

    // MARK: - Life-cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        let theme = ThemeManager.theme(for: traitCollection.userInterfaceStyle)

        suggestionBar = SuggestionBarView(theme: theme)
        suggestionBar.delegate = self
        suggestionBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(suggestionBar)

        keyboardView = KeyboardView(state: state, theme: theme)
        keyboardView.delegate = self
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)

        NSLayoutConstraint.activate([
            suggestionBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            suggestionBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            suggestionBar.topAnchor.constraint(equalTo: view.topAnchor),
            suggestionBar.heightAnchor.constraint(equalToConstant: 44),

            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.topAnchor.constraint(equalTo: suggestionBar.bottomAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Total keyboard height (letter portion + suggestion bar).
        heightConstraint = view.heightAnchor.constraint(equalToConstant: 260)
        heightConstraint.priority = .required - 1
        heightConstraint.isActive = true

        updateShiftForContext()
        refreshSuggestions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateShiftForContext()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateShiftForContext()
        refreshSuggestions()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        let theme = ThemeManager.theme(for: traitCollection.userInterfaceStyle)
        keyboardView.apply(theme: theme)
        suggestionBar.apply(theme: theme)
    }

    // MARK: - Shift auto-behaviour

    /// iOS-standard: when the field is empty or the previous character is a sentence terminator,
    /// automatically shift to uppercase (one-shot).
    private func updateShiftForContext() {
        guard state.shiftMode != .capsLock else { return }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let trimmed = before.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldShift: Bool
        if before.isEmpty {
            shouldShift = true
        } else if let last = trimmed.last, ".!?".contains(last) {
            shouldShift = true
        } else if trimmed.isEmpty {
            shouldShift = true
        } else {
            shouldShift = false
        }
        state.shiftMode = shouldShift ? .uppercase : .lowercase
        keyboardView.refreshForStateChange()
    }

    // MARK: - Suggestions

    private func refreshSuggestions() {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        // Partial word = trailing letters not followed by whitespace.
        var partial = ""
        for ch in before.reversed() {
            if ch.isLetter { partial = String(ch) + partial } else { break }
        }
        let results = engine.predict(contextBefore: before, partial: partial.isEmpty ? nil : partial)
        var strings: [String] = []
        var autoIndex: Int? = nil

        // Autocorrect fallback for the partial word.
        if !partial.isEmpty,
           SharedDefaults.bool(SharedDefaults.Key.autocorrectEnabled, default: true),
           let corrected = engine.autocorrect(partial, contextBefore: String(before.dropLast(partial.count))) {
            strings.append(partial)
            strings.append(corrected)
            autoIndex = 1
            for r in results where !strings.contains(r.word) {
                if strings.count >= 3 { break }
                strings.append(r.word)
            }
        } else {
            for r in results {
                strings.append(r.word)
                if strings.count >= 3 { break }
            }
        }
        while strings.count < 3 { strings.append("") }
        suggestionBar.setSuggestions(strings, autocorrectIndex: autoIndex)
    }

    // MARK: - Text mutation helpers

    /// Insert `text`. Emits haptic + sound and re-computes suggestions.
    private func insert(_ text: String) {
        textDocumentProxy.insertText(text)
        engine.store.recordKeystroke()
        HapticManager.shared.tap()
        SoundManager.tap()

        // Word-commit — space/newline/punctuation completes a word for learning.
        if text.count == 1, let ch = text.first, isWordTerminator(ch) {
            commitLastWord()
        }
        updateShiftForContext()
        refreshSuggestions()
    }

    private func isWordTerminator(_ ch: Character) -> Bool {
        return ch == " " || ch == "\n" || ch == "\t" || ".!?,;:)]".contains(ch)
    }

    /// Called after word terminator — learn the most recently completed word into the n-gram store.
    private func commitLastWord() {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let tokens = PredictionEngine.tokenize(before)
        guard !tokens.isEmpty else { return }
        // Learn last 3 tokens as trigram context.
        let ctx = Array(tokens.suffix(3))
        engine.store.learn(words: ctx)
    }

    private func deleteBackward() {
        textDocumentProxy.deleteBackward()
        HapticManager.shared.delete()
        SoundManager.delete()
        updateShiftForContext()
        refreshSuggestions()
    }
}

// MARK: - KeyboardViewDelegate

extension KeyboardViewController: KeyboardViewDelegate {
    func keyboardView(_ view: KeyboardView, didTap definition: KeyDefinition) {
        switch definition.type {
        case .letter:
            let ch = state.isShifted && state.page == .letters ? definition.shifted : definition.primary
            insert(ch)
            state.resetShiftAfterLetter()
            keyboardView.refreshForStateChange()

        case .shift:
            let now = Date()
            if let last = lastShiftTap, now.timeIntervalSince(last) < 0.3 {
                state.enableCapsLock()
            } else {
                state.toggleShift()
            }
            lastShiftTap = now
            HapticManager.shared.shift()
            SoundManager.modifier()
            keyboardView.refreshForStateChange()

        case .backspace:
            deleteBackward()

        case .space:
            insert(" ")

        case .returnKey:
            insert("\n")

        case .switchMode:
            switch state.page {
            case .letters:  state.page = .symbols1
            case .symbols1: state.page = .symbols2
            case .symbols2: state.page = .letters
            }
            // The switch key label for symbols pages is context-sensitive:
            // "ABC" goes back to letters, "#+=" swaps between symbol pages.
            SoundManager.modifier()
            keyboardView.refreshForStateChange()

        case .nextKeyboard:
            advanceToNextInputMode()

        case .special:
            break
        }
    }

    func keyboardView(_ view: KeyboardView, didHold definition: KeyDefinition, resolved character: String) {
        insert(character)
        state.resetShiftAfterLetter()
        keyboardView.refreshForStateChange()
    }

    func keyboardViewBackspaceRepeat(_ view: KeyboardView) {
        deleteBackward()
    }

    func keyboardViewNextKeyboardEvent(_ view: KeyboardView, sender: UIView, event: UIEvent?) {
        // The globe key long-press behaviour is handled by the system when
        // handleInputModeList(from:with:) is called on a UITouchEvent. For tap,
        // we cycle to the next mode in didTap.
    }
}

// MARK: - SuggestionBarDelegate

extension KeyboardViewController: SuggestionBarDelegate {
    func suggestionBar(_ bar: SuggestionBarView, didSelect suggestion: String, isAutocorrect: Bool) {
        guard !suggestion.isEmpty else { return }
        // Remove the partial word (letters) preceding the caret.
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        var partialCount = 0
        for ch in before.reversed() {
            if ch.isLetter { partialCount += 1 } else { break }
        }
        for _ in 0..<partialCount { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(suggestion + " ")
        engine.store.accept(word: suggestion)
        HapticManager.shared.tap()
        commitLastWord()
        updateShiftForContext()
        refreshSuggestions()
    }
}
