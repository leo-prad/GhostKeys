import SwiftUI

struct MainView: View {
    @AppStorage(SharedDefaults.Key.hapticsEnabled, store: SharedDefaults.store) private var haptics = true
    @AppStorage(SharedDefaults.Key.soundEnabled, store: SharedDefaults.store) private var sound = false
    @AppStorage(SharedDefaults.Key.autocorrectEnabled, store: SharedDefaults.store) private var autocorrect = true
    @State private var showClearAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section("Welcome") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GhostKeys")
                            .font(.largeTitle).bold()
                        Text("A native iOS keyboard with Gboard-style long-press symbols and adaptive next-word prediction.")
                            .foregroundStyle(.secondary)
                    }.padding(.vertical, 6)
                }

                Section("Setup") {
                    Label("Open Settings → General → Keyboard → Keyboards", systemImage: "1.circle.fill")
                    Label("Tap “Add New Keyboard…” and choose GhostKeys", systemImage: "2.circle.fill")
                    Label("Tap GhostKeys and enable “Allow Full Access”", systemImage: "3.circle.fill")
                    Label("In any text field, long-press 🌐 to switch to GhostKeys", systemImage: "4.circle.fill")
                }

                Section("Try it") {
                    TextEditor(text: .constant(""))
                        .frame(minHeight: 120)
                        .overlay(alignment: .topLeading) {
                            Text("Tap here and switch to GhostKeys to test…")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8).padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                }

                Section("Preferences") {
                    Toggle("Haptic feedback", isOn: $haptics)
                    Toggle("Key click sound", isOn: $sound)
                    Toggle("Autocorrect", isOn: $autocorrect)
                }

                Section {
                    Button(role: .destructive) { showClearAlert = true } label: {
                        Label("Clear learned data", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("GhostKeys")
            .alert("Clear learned data?", isPresented: $showClearAlert) {
                Button("Clear", role: .destructive) { clearLearned() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Removes every learned word, phrase, and typo correction. Your typing will start from scratch.")
            }
        }
    }

    private func clearLearned() {
        NGramStore().clearAll()
    }
}

#Preview { MainView() }
