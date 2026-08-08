# GhostKeys — Native iOS Custom Keyboard

A custom iPhone keyboard with:

- **iOS-native look** — QWERTY layout, key shapes, light/dark theme.
- **Gboard-style long-press** — hold any letter to insert numbers, punctuation, or accents.
- **Adaptive next-word prediction** — learns from your typing (unigrams, bigrams, trigrams with recency boost).
- **Damerau-Levenshtein autocorrect** with keyboard-adjacency scoring and contextual re-ranking.
- **Haptic + sound feedback**, one-shot shift, caps lock, three symbol pages, backspace repeat.

Everything is native Swift (SwiftUI host app + UIKit keyboard extension via `UIInputViewController`). No third-party dependencies.

## Repository layout

```
GhostKeys/
├── project.yml                    # XcodeGen config — generates GhostKeys.xcodeproj
├── Shared/                        # Files compiled into both targets
│   ├── AppGroupConstants.swift
│   ├── SharedDefaults.swift
│   └── NGramStore.swift
├── GhostKeys/                     # Host app (SwiftUI)
│   ├── GhostKeysApp.swift
│   ├── MainView.swift
│   ├── Info.plist
│   └── GhostKeys.entitlements
└── GhostKeyboard/                 # Keyboard extension
    ├── KeyboardViewController.swift
    ├── Info.plist
    ├── GhostKeyboard.entitlements
    ├── Models/                    # Key, layout, state
    ├── Views/                     # KeyButton, KeyboardView, SuggestionBar, Popup
    ├── Prediction/                # Engine, PersonalDictionary, PredictionResult
    ├── Utilities/                 # Haptics, sound, theme
    └── Resources/lexicon.json     # Top ~8k English words w/ subtitle-corpus frequencies
```

## Build on a Mac (Xcode)

The project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) so no `.xcodeproj` XML lives in the repo.

```bash
brew install xcodegen
cd GhostKeys
xcodegen generate
open GhostKeys.xcodeproj
```

In Xcode:

1. Select the **GhostKeys** scheme.
2. Under Signing & Capabilities for **both** targets:
   - Set Team to your Apple ID.
   - The App Group `group.com.ghostkeys.shared` should already be present via the `.entitlements` files — enable it in the capabilities pane so Xcode registers it with your team.
3. Plug in your iPhone (iOS 17+) and Run.

## Install on device

1. After the first run installs the host app, on the phone open **Settings → General → Keyboard → Keyboards → Add New Keyboard…** and pick **GhostKeys**.
2. Tap **GhostKeys** in the list and enable **Allow Full Access** (required for persistent learned-word storage in the App Group container).
3. Open any text field, long-press 🌐, switch to GhostKeys.

## Sideload for long-term use (no paid dev account)

- Archive → Export → save the `.ipa`.
- Transfer to Windows, install via AltStore / AltServer — it re-signs weekly.

## Notes

- Bundled lexicon is ~130 KB (top 8 000 words from FrequencyWords en_50k subtitles). Keyboard extensions are capped at 48 MB — this leaves ample room.
- `NGramStore` persists to the App Group container as JSON with debounced 250 ms flushes.
- Prediction engine is a direct port of the JS reference in `../ghostkeys-simulator.html`. Behaviour parity was the design goal — see the JS source for the algorithm rationale.
