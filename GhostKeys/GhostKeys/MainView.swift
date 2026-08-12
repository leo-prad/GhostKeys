import SwiftUI

struct MainView: View {
    @AppStorage(SharedDefaults.Key.autoCapitalizationEnabled, store: SharedDefaults.store) private var autoCapitalization = true
    @AppStorage(SharedDefaults.Key.charPreviewEnabled, store: SharedDefaults.store) private var charPreview = true
    @AppStorage(SharedDefaults.Key.soundEnabled, store: SharedDefaults.store) private var sound = false
    @AppStorage(SharedDefaults.Key.hapticsEnabled, store: SharedDefaults.store) private var haptics = true
    @AppStorage(SharedDefaults.Key.specialHapticsEnabled, store: SharedDefaults.store) private var specialHaptics = true
    @AppStorage(SharedDefaults.Key.doubleSpacePeriodEnabled, store: SharedDefaults.store) private var doubleSpacePeriod = true
    @AppStorage(SharedDefaults.Key.autocorrectEnabled, store: SharedDefaults.store) private var autocorrect = true
    @AppStorage(SharedDefaults.Key.holdDelayMs, store: SharedDefaults.store) private var holdDelayMs = 350
    @AppStorage(SharedDefaults.Key.backspaceSpeedMs, store: SharedDefaults.store) private var backspaceSpeedMs = 80
    @AppStorage(SharedDefaults.Key.doubleSpacePeriodMs, store: SharedDefaults.store) private var doubleSpacePeriodMs = 300
    @AppStorage(SharedDefaults.Key.glideTriggerMs, store: SharedDefaults.store) private var glideTriggerMs = 80
    @AppStorage(SharedDefaults.Key.deleteGlideWordEnabled, store: SharedDefaults.store) private var deleteGlideWord = true
    @AppStorage(SharedDefaults.Key.caseMatchReplacementsEnabled, store: SharedDefaults.store) private var caseMatchReplacements = false

    @State private var testText: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Welcome") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GhostKeys")
                            .font(.title2).bold()
                        Text("A native iOS keyboard with Gboard-style long-press symbols and adaptive next-word prediction.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }

                Section("Setup") {
                    Label("Open Settings → General → Keyboard → Keyboards", systemImage: "1.circle.fill")
                    Label("Tap “Add New Keyboard…” and choose GhostKeys", systemImage: "2.circle.fill")
                    Label("Tap GhostKeys and enable “Allow Full Access”", systemImage: "3.circle.fill")
                    Label("In any text field, tap or long-press 😀 to switch keyboards", systemImage: "4.circle.fill")
                }

                Section("Try It") {
                    TextField("Tap here to test typing...", text: $testText, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(.vertical, 4)
                }

                Section("Typing") {
                    Toggle("Auto-Capitalization", isOn: $autoCapitalization)
                    Toggle("Character Preview", isOn: $charPreview)
                    Toggle("Keyboard Sounds", isOn: $sound)
                    Toggle("Typing Haptics", isOn: $haptics)
                    Toggle("Special Character Haptics", isOn: $specialHaptics)
                    Toggle("“.” Shortcut", isOn: $doubleSpacePeriod)
                    Toggle("Autocorrect", isOn: $autocorrect)
                    Toggle("Delete Glide Word with Backspace", isOn: $deleteGlideWord)
                    Toggle("Match Case in Text Replacement", isOn: $caseMatchReplacements)
                }

                Section("Key Presses") {
                    Stepper(value: $holdDelayMs, in: 150...1000, step: 25) {
                        HStack {
                            Text("Hold for Special Characters")
                            Spacer()
                            Text("\(holdDelayMs) ms")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Stepper(value: $backspaceSpeedMs, in: 20...500, step: 5) {
                        HStack {
                            Text("Backspace Delete Speed")
                            Spacer()
                            Text("\(backspaceSpeedMs) ms")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Stepper(value: $glideTriggerMs, in: 0...500, step: 25) {
                        HStack {
                            Text("Glide Typing Trigger")
                            Spacer()
                            Text("\(glideTriggerMs) ms")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Stepper(value: $doubleSpacePeriodMs, in: 100...1000, step: 25) {
                        HStack {
                            Text("Double-Space Period Window")
                            Spacer()
                            Text("\(doubleSpacePeriodMs) ms")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Dictionary") {
                    NavigationLink(destination: LearnedWordsView()) {
                        HStack {
                            Text("Learned Words")
                            Spacer()
                        }
                    }

                    NavigationLink(destination: TextReplacementView()) {
                        HStack {
                            Text("Text Replacement")
                            Spacer()
                        }
                    }
                }
            }
            .font(.subheadline)
            .listStyle(.plain)
            .listSectionSpacing(.compact)
            .navigationTitle("Keyboard Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Learned Words Detail View

struct LearnedWordsView: View {
    @State private var store = NGramStore()
    @State private var words: [String] = []
    @State private var searchText = ""
    @State private var newWordText = ""
    @State private var showClearAlert = false

    var filteredWords: [String] {
        if searchText.isEmpty {
            return words
        }
        return words.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Add word", text: $newWordText)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    Button("Add") {
                        addWord()
                    }
                    .disabled(newWordText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Section(header: Text("Learned Dictionary (\(filteredWords.count))")) {
                if filteredWords.isEmpty {
                    Text("No learned words")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredWords, id: \.self) { word in
                        Text(word)
                    }
                    .onDelete(perform: deleteWords)
                }
            }

            Section {
                Button(role: .destructive) {
                    showClearAlert = true
                } label: {
                    Label("Clear learned data", systemImage: "trash")
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search dictionary")
        .navigationTitle("Learned Words")
        .onAppear(perform: reloadWords)
        .alert("Clear learned data?", isPresented: $showClearAlert) {
            Button("Clear", role: .destructive) {
                store.clearAll()
                reloadWords()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes every learned word, phrase, and typo correction. Your typing will start from scratch.")
        }
    }

    private func reloadWords() {
        words = store.getLearnedWords()
    }

    private func addWord() {
        let trimmed = newWordText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.addWord(trimmed)
        newWordText = ""
        reloadWords()
    }

    private func deleteWords(at offsets: IndexSet) {
        for index in offsets {
            let word = filteredWords[index]
            store.removeWord(word)
        }
        reloadWords()
    }
}

// MARK: - Text Replacement Detail View

struct TextReplacementView: View {
    @State private var items: [TextReplacementItem] = []
    @State private var searchText = ""
    @State private var showAddSheet = false

    var filteredItems: [TextReplacementItem] {
        if searchText.isEmpty { return items }
        return items.filter {
            $0.phrase.localizedCaseInsensitiveContains(searchText) ||
            $0.shortcut.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            if filteredItems.isEmpty {
                Text("No text replacements found")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredItems) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.phrase)
                                .font(.body)
                            Text(item.shortcut)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .onDelete(perform: deleteItems)
            }
        }
        .searchable(text: $searchText, prompt: "Search")
        .navigationTitle("Text Replacement")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTextReplacementView { newItem in
                items.append(newItem)
                SharedDefaults.saveTextReplacements(items)
            }
        }
        .onAppear {
            items = SharedDefaults.getTextReplacements()
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let toRemove = offsets.map { filteredItems[$0] }
        items.removeAll(where: { item in toRemove.contains(where: { $0.id == item.id }) })
        SharedDefaults.saveTextReplacements(items)
    }
}

// MARK: - Add Text Replacement Sheet

struct AddTextReplacementView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var phrase: String = ""
    @State private var shortcut: String = ""

    var onSave: (TextReplacementItem) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Phrase")
                            .frame(width: 80, alignment: .leading)
                        TextField("Required", text: $phrase)
                    }
                    HStack {
                        Text("Shortcut")
                            .frame(width: 80, alignment: .leading)
                        TextField("Optional", text: $shortcut)
                    }
                } footer: {
                    Text("Create a shortcut that will automatically expand into the word or phrase as you type.")
                }
            }
            .navigationTitle("Text Replacement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newItem = TextReplacementItem(phrase: phrase.trimmingCharacters(in: .whitespacesAndNewlines),
                                                           shortcut: shortcut.trimmingCharacters(in: .whitespacesAndNewlines))
                        onSave(newItem)
                        dismiss()
                    }
                    .disabled(phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    MainView()
}
