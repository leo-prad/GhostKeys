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
    private var pendingGlideSeparator = false
    private var lastGlideWord: String?
    private var lastSpaceTap: TimeInterval?
    private var contextRefreshWorkItem: DispatchWorkItem?

    // MARK: - Life-cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.clipsToBounds = false

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
            suggestionBar.heightAnchor.constraint(equalToConstant: 36),

            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.topAnchor.constraint(equalTo: suggestionBar.bottomAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Total keyboard height (letter portion + suggestion bar).
        heightConstraint = view.heightAnchor.constraint(equalToConstant: 244)
        heightConstraint.priority = .required - 1
        heightConstraint.isActive = true

        updateShiftForContext()
        refreshSuggestions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Pull the latest host-app settings when iOS reactivates the extension.
        SharedDefaults.store.synchronize()
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
        guard SharedDefaults.bool(SharedDefaults.Key.autoCapitalizationEnabled, default: true) else {
            if state.shiftMode != .capsLock {
                state.shiftMode = .lowercase
                keyboardView.refreshForStateChange()
            }
            return
        }
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
        let actualBefore = textDocumentProxy.documentContextBeforeInput ?? ""
        // A glide word keeps a virtual trailing space until the next input so
        // punctuation can attach cleanly while suggestions remain next-word suggestions.
        let before = pendingGlideSeparator ? actualBefore + " " : actualBefore
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
        if state.shiftMode == .capsLock {
            strings = strings.map { $0.uppercased() }
        }
        suggestionBar.setSuggestions(strings, autocorrectIndex: autoIndex)
    }

    // MARK: - Text mutation helpers

    /// Insert `text`. Emits haptic + sound and re-computes suggestions.
    private func insert(_ text: String) {
        if text == " " {
            let now = ProcessInfo.processInfo.systemUptime
            let before = textDocumentProxy.documentContextBeforeInput ?? ""
            let window = SharedDefaults.double(SharedDefaults.Key.doubleSpacePeriodMs, default: 300) / 1000
            let precedingFirstSpace = before.dropLast().last
            let isTimedSecondSpace = lastSpaceTap.map { now - $0 <= window } ?? false

            if SharedDefaults.bool(SharedDefaults.Key.doubleSpacePeriodEnabled, default: true),
               isTimedSecondSpace,
               before.last == " ",
               let precedingFirstSpace,
               !precedingFirstSpace.isWhitespace {
                textDocumentProxy.deleteBackward()
                textDocumentProxy.insertText(". ")
                lastSpaceTap = nil
                engine.store.recordKeystroke()
                if SharedDefaults.bool(SharedDefaults.Key.hapticsEnabled, default: true) { HapticManager.shared.tap() }
                if SharedDefaults.bool(SharedDefaults.Key.soundEnabled, default: false) { SoundManager.tap() }
                updateShiftForContext()
                refreshSuggestions()
                return
            }
            lastSpaceTap = now
        } else {
            lastSpaceTap = nil
        }

        // Text replacement and autocorrect checks on word completion.
        if text.count == 1, let ch = text.first, isWordTerminator(ch) {
            let before = textDocumentProxy.documentContextBeforeInput ?? ""
            var partial = ""
            for c in before.reversed() {
                if c.isLetter || c.isNumber { partial = String(c) + partial } else { break }
            }
            if !partial.isEmpty {
                let replacements = SharedDefaults.getTextReplacements()
                if let match = replacements.first(where: { $0.shortcut.lowercased() == partial.lowercased() }) {
                    for _ in 0..<partial.count { textDocumentProxy.deleteBackward() }
                    let phrase = caseMatched(replacement: match.phrase, typed: partial)
                    textDocumentProxy.insertText(phrase)
                } else if SharedDefaults.bool(SharedDefaults.Key.autocorrectEnabled, default: true),
                          let corrected = engine.autocorrect(partial, contextBefore: String(before.dropLast(partial.count))),
                          corrected != partial {
                    for _ in 0..<partial.count { textDocumentProxy.deleteBackward() }
                    textDocumentProxy.insertText(corrected)
                    pendingAutocorrectTyped = partial
                    pendingAutocorrectCorrected = corrected
                }
            }
        }

        textDocumentProxy.insertText(text)
        engine.store.recordKeystroke()
        if SharedDefaults.bool(SharedDefaults.Key.hapticsEnabled, default: true) { HapticManager.shared.tap() }
        if SharedDefaults.bool(SharedDefaults.Key.soundEnabled, default: false) { SoundManager.tap() }

        // Word-commit — space/newline/punctuation completes a word for learning.
        if text.count == 1, let ch = text.first, isWordTerminator(ch) {
            commitLastWord()
        }
        updateShiftForContext()
        refreshSuggestions()
    }

    /// Adjust a text-replacement phrase's casing to match how the shortcut was typed.
    /// - Shortcut all-caps (e.g. "BRB")  → phrase upper-cased ("BE RIGHT BACK!")
    /// - Shortcut Title-cased ("Brb")    → phrase's first letter capitalized
    /// - Otherwise                        → phrase unchanged
    /// Only active when caseMatchReplacementsEnabled is set.
    private func caseMatched(replacement phrase: String, typed: String) -> String {
        guard SharedDefaults.bool(SharedDefaults.Key.caseMatchReplacementsEnabled, default: false) else {
            return phrase
        }
        let letters = typed.filter { $0.isLetter }
        guard letters.count > 1 else { return phrase }
        if letters == letters.uppercased() && letters != letters.lowercased() {
            return phrase.uppercased()
        }
        if let first = letters.first, first.isUppercase,
           letters.dropFirst().allSatisfy({ $0.isLowercase }) {
            guard let firstPhrase = phrase.first else { return phrase }
            return firstPhrase.uppercased() + phrase.dropFirst()
        }
        return phrase
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
        if SharedDefaults.bool(SharedDefaults.Key.hapticsEnabled, default: true) { HapticManager.shared.delete() }
        if SharedDefaults.bool(SharedDefaults.Key.soundEnabled, default: false) { SoundManager.delete() }
        scheduleContextRefresh()
    }

    private func scheduleContextRefresh() {
        contextRefreshWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.updateShiftForContext()
            self?.refreshSuggestions()
        }
        contextRefreshWorkItem = work
        DispatchQueue.main.async(execute: work)
    }

    private func deleteLastGlideWordIfNeeded() -> Bool {
        guard pendingGlideSeparator,
              SharedDefaults.bool(SharedDefaults.Key.deleteGlideWordEnabled, default: true),
              let word = lastGlideWord,
              (textDocumentProxy.documentContextBeforeInput ?? "").hasSuffix(word) else { return false }

        for _ in word { textDocumentProxy.deleteBackward() }
        HapticManager.shared.delete()
        SoundManager.delete()
        pendingGlideSeparator = false
        lastGlideWord = nil
        scheduleContextRefresh()
        return true
    }

    private func deletePreviousWords(_ count: Int) {
        guard count > 0 else { return }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let characters = Array(before)
        var index = characters.count
        var words = 0

        while index > 0, words < count {
            while index > 0, characters[index - 1].isWhitespace { index -= 1 }
            guard index > 0 else { break }
            while index > 0, !characters[index - 1].isWhitespace { index -= 1 }
            words += 1
        }

        let deleteCount = characters.count - index
        guard deleteCount > 0 else { return }
        for _ in 0..<deleteCount { textDocumentProxy.deleteBackward() }
        HapticManager.shared.delete()
        SoundManager.delete()
        scheduleContextRefresh()
    }

    private func isAttachedPunctuation(_ text: String) -> Bool {
        guard text.count == 1, let character = text.first else { return false }
        return ".,!?;:%)]}\"…¿¡".contains(character)
    }

    private func isWordJoiner(_ text: String) -> Bool {
        guard text.count == 1, let character = text.first else { return false }
        return "'’‘-–—".contains(character)
    }

    private func prepareForManualCharacter(_ text: String) {
        guard pendingGlideSeparator else { return }
        if isAttachedPunctuation(text) {
            // Terminal punctuation attaches now and still needs a separator
            // before the next manually typed word.
            pendingGlideSeparator = true
        } else if isWordJoiner(text) {
            // Apostrophes and dashes join the current word to what follows.
            pendingGlideSeparator = false
            lastGlideWord = nil
        } else {
            insert(" ")
            pendingGlideSeparator = false
            lastGlideWord = nil
        }
    }
}

// MARK: - KeyboardViewDelegate

extension KeyboardViewController: KeyboardViewDelegate {
    func keyboardView(_ view: KeyboardView, didTap definition: KeyDefinition) {
        switch definition.type {
        case .letter:
            let ch = state.isShifted && state.page == .letters ? definition.shifted : definition.primary
            prepareForManualCharacter(ch)
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
            if !deleteLastGlideWordIfNeeded() {
                let context = textDocumentProxy.documentContextBeforeInput ?? ""
                let isDeletingAttachedPunctuation = pendingGlideSeparator &&
                    lastGlideWord.map { !context.hasSuffix($0) } == true
                deleteBackward()
                if !isDeletingAttachedPunctuation {
                    pendingGlideSeparator = false
                    lastGlideWord = nil
                }
            }

        case .space:
            pendingGlideSeparator = false
            lastGlideWord = nil
            insert(" ")
            // iOS-standard: tapping space on the symbol pages returns to letters.
            if state.page != .letters {
                state.page = .letters
                keyboardView.refreshForStateChange()
            }

        case .returnKey:
            pendingGlideSeparator = false
            lastGlideWord = nil
            insert("\n")

        case .switchMode:
            if definition.primary == "ABC" {
                state.page = .letters
            } else if definition.primary == "#+=" {
                state.page = .symbols2
            } else if definition.primary == "123" {
                state.page = .symbols1
            } else {
                switch state.page {
                case .letters:  state.page = .symbols1
                case .symbols1: state.page = .letters
                case .symbols2: state.page = .letters
                }
            }
            SoundManager.modifier()
            keyboardView.refreshForStateChange()

        case .nextKeyboard:
            advanceToNextInputMode()

        case .special:
            break
        }
    }

    func keyboardView(_ view: KeyboardView, didHold definition: KeyDefinition, resolved character: String) {
        prepareForManualCharacter(character)
        insert(character)
        state.resetShiftAfterLetter()
        keyboardView.refreshForStateChange()
    }

    func keyboardView(_ view: KeyboardView, didGlide trace: [String]) {
        guard let decoded = engine.decodeGlide(trace) else {
            if let first = trace.first {
                let fallback = state.isShifted ? first.uppercased() : first
                insert(fallback)
                state.resetShiftAfterLetter()
                keyboardView.refreshForStateChange()
            }
            return
        }
        let word: String
        if state.shiftMode == .capsLock {
            word = decoded.uppercased()
        } else if state.isShifted {
            word = decoded.prefix(1).uppercased() + decoded.dropFirst()
        } else {
            word = decoded
        }
        if pendingGlideSeparator { insert(" ") }
        pendingGlideSeparator = false
        insert(word)
        pendingGlideSeparator = true
        lastGlideWord = word
        refreshSuggestions()
        state.resetShiftAfterLetter()
        keyboardView.refreshForStateChange()
    }

    func keyboardViewBackspaceRepeat(_ view: KeyboardView) {
        pendingGlideSeparator = false
        lastGlideWord = nil
        deleteBackward()
    }

    func keyboardView(_ view: KeyboardView, deleteWords count: Int) {
        deletePreviousWords(count)
    }

    func keyboardViewNextKeyboardEvent(_ view: KeyboardView, sender: UIView, event: UIEvent?) {
        // The globe key long-press behaviour is handled by the system when
        // handleInputModeList(from:with:) is called on a UITouchEvent. For tap,
        // we cycle to the next mode in didTap.
    }

    // MARK: - Hold-space cursor drag

    func keyboardViewSpaceCursorBegan(_ view: KeyboardView) {
        // Any pending glide state is stale once the user is scrubbing the caret.
        pendingGlideSeparator = false
        lastGlideWord = nil
    }

    func keyboardViewSpaceCursorMove(_ view: KeyboardView, characterOffset: Int) {
        guard characterOffset != 0 else { return }
        textDocumentProxy.adjustTextPosition(byCharacterOffset: characterOffset)
    }

    func keyboardViewSpaceCursorEnded(_ view: KeyboardView) {
        updateShiftForContext()
        refreshSuggestions()
    }
}

// MARK: - SuggestionBarDelegate

extension KeyboardViewController: SuggestionBarDelegate {
    func suggestionBar(_ bar: SuggestionBarView, didSelect suggestion: String, isAutocorrect: Bool) {
        guard !suggestion.isEmpty else { return }
        if pendingGlideSeparator {
            textDocumentProxy.insertText(" " + suggestion + " ")
            pendingGlideSeparator = false
            lastGlideWord = nil
            engine.store.accept(word: suggestion)
            HapticManager.shared.tap()
            commitLastWord()
            updateShiftForContext()
            refreshSuggestions()
            return
        }
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
