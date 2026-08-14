# iOS Custom Keyboard — Full Build Plan

## Project Overview

Build a custom iOS keyboard extension for iPhone 15 Pro that combines:
- **iOS-native visual style** — matches the stock Apple keyboard look (layout, key shapes, colors, font)
- **Gboard-like smart prediction** — learns words/phrases from usage, suggests contextually
- **Hold-for-special-characters** — long-press any letter to access punctuation/symbols (like Gboard)

Target: iPhone 15 Pro, iOS 17+. Built as a standard Xcode project with a host app + keyboard extension.

---

## Project Structure

```
GhostKeys/
├── GhostKeys.xcodeproj
├── GhostKeys/                          # Host app (required container app)
│   ├── AppDelegate.swift
│   ├── MainViewController.swift        # Simple onboarding screen with setup instructions
│   ├── Assets.xcassets
│   ├── Info.plist
│   └── LaunchScreen.storyboard
├── GhostKeyboard/                      # Keyboard extension target
│   ├── KeyboardViewController.swift    # Entry point — UIInputViewController subclass
│   ├── Info.plist                      # Extension plist with NSExtension config
│   ├── Views/
│   │   ├── KeyboardView.swift          # Main keyboard layout container
│   │   ├── KeyButton.swift             # Individual key view with press/hold states
│   │   ├── KeyRow.swift                # Horizontal row of keys
│   │   ├── SuggestionBarView.swift     # Top prediction/suggestion strip
│   │   └── PopupKeyView.swift          # The hold-to-select character popup
│   ├── Models/
│   │   ├── KeyboardLayout.swift        # Layout definitions (QWERTY rows, key sizes)
│   │   ├── KeyDefinition.swift         # Data model for each key (letter, width, hold chars)
│   │   └── KeyboardState.swift         # Tracks shift/caps/symbols mode
│   ├── Prediction/
│   │   ├── PredictionEngine.swift      # Core n-gram prediction logic
│   │   ├── NGramStore.swift            # Persistent storage for learned n-grams
│   │   ├── PersonalDictionary.swift    # User-added words + frequency tracking
│   │   └── PredictionResult.swift      # Data model for ranked suggestions
│   ├── Gestures/
│   │   ├── KeyPressHandler.swift       # Tap, long-press, repeat gesture coordinator
│   │   └── HoldCharacterPicker.swift   # Long-press popup character selection logic
│   └── Utilities/
│       ├── HapticManager.swift         # Taptic feedback on keypress
│       ├── SoundManager.swift          # Optional key click sounds
│       ├── ThemeManager.swift          # Light/dark mode color tokens
│       └── SharedDefaults.swift        # App group UserDefaults wrapper
└── Shared/
    └── AppGroupConstants.swift         # App group identifier shared between targets
```

---

## Phase 1: Xcode Project Skeleton + Bare Keyboard

**Goal:** A keyboard extension that loads and shows a single-color background. Proves the build pipeline works.

### Tasks:
1. Create the Xcode project `GhostKeys` with an iOS App target (SwiftUI or UIKit — UIKit is easier for the keyboard)
2. Add a **Custom Keyboard Extension** target called `GhostKeyboard`
3. Configure `GhostKeyboard/Info.plist`:
   ```xml
   <key>NSExtension</key>
   <dict>
       <key>NSExtensionAttributes</key>
       <dict>
           <key>IsASCIICapable</key>
           <true/>
           <key>PrefersRightToLeft</key>
           <false/>
           <key>PrimaryLanguage</key>
           <string>en-US</string>
           <key>RequestsOpenAccess</key>
           <true/>  <!-- Needed for learning/storing user data -->
       </dict>
       <key>NSExtensionPointIdentifier</key>
       <string>com.apple.keyboard-service</string>
       <key>NSExtensionPrincipalClass</key>
       <string>${PRODUCT_MODULE_NAME}.KeyboardViewController</string>
   </dict>
   ```
4. Set up an **App Group** (e.g., `group.com.ghostkeys.shared`) on both targets so the keyboard extension and host app can share UserDefaults/files
5. `KeyboardViewController.swift` — subclass `UIInputViewController`, override `viewDidLoad`, add a placeholder colored UIView
6. Host app `MainViewController` — simple screen saying "Go to Settings > General > Keyboard > Keyboards > Add New Keyboard > GhostKeys"
7. Verify it builds, installs on device, and appears in the keyboard list

---

## Phase 2: Keyboard Layout + Key Rendering

**Goal:** Full QWERTY layout that looks like the stock iOS keyboard and actually types.

### KeyDefinition Model
```swift
struct KeyDefinition {
    let primary: String           // "q", "w", etc.
    let shifted: String           // "Q", "W", etc.
    let holdCharacters: [String]  // e.g., ["1", "!", "|"] for Q key
    let widthMultiplier: CGFloat  // 1.0 = standard, 1.5 = shift, 2.0+ = space
    let type: KeyType             // .letter, .shift, .backspace, .space, .return, .switchMode, .nextKeyboard
}

enum KeyType {
    case letter, shift, backspace, space, returnKey, switchMode, nextKeyboard, special
}
```

### KeyboardLayout
Define three pages:
- **Letters (lowercase/uppercase):** standard QWERTY — row1: QWERTYUIOP, row2: ASDFGHJKL, row3: shift+ZXCVBNM+backspace, row4: 123+globe+space+return
- **Numbers/Symbols page 1:** 1234567890, -/:;()$&@", #+shift+.,?!'+backspace, ABC+globe+space+return
- **Numbers/Symbols page 2:** []{}#%^*+=, _\|~<>€£¥·, #+shift+.,?!'+backspace, ABC+globe+space+return

### Key Sizing Logic
- Measure total keyboard width from `view.bounds.width`
- Standard key width = (total width - all inter-key spacing) / 10  (for the 10-key top row)
- Row 2 has 9 keys with extra left/right padding to center them
- Row 3: shift and backspace are ~1.5x width
- Row 4: space bar takes remaining space after fixed-width keys
- Key height: roughly 42-46pt on iPhone 15 Pro (adjust to feel right)
- Inter-key spacing: ~6pt horizontal, ~12pt vertical
- Corner radius: ~5pt

### KeyButton View
- UIView-based (not UIButton — more control)
- Rendering:
  - Light mode: white key (#FFFFFF) with subtle shadow, dark text
  - Dark mode: dark gray key (#4A4A4C) with lighter text
  - Special keys (shift, backspace, return, mode switch): medium gray (#AEB3BF light / #636366 dark)
- Font: San Francisco (system font) at ~22pt for letters, ~16pt for special key labels
- States: normal, highlighted (darker shade on press), shifted
- On tap → calls `textDocumentProxy.insertText(character)` via a delegate callback

### KeyboardState
```swift
class KeyboardState: ObservableObject {
    var shiftMode: ShiftMode = .lowercase  // .lowercase, .uppercase, .capsLock
    var currentPage: KeyboardPage = .letters // .letters, .symbols1, .symbols2
}
```
- Shift behavior: single tap → type one uppercase letter → return to lowercase. Double-tap → caps lock (visual indicator on shift key)
- Backspace: single tap deletes one character. Hold → starts repeating delete after 0.5s delay, accelerating

### Integration in KeyboardViewController
- Build the view hierarchy: SuggestionBarView on top + KeyboardView below
- KeyboardView creates KeyRows, each KeyRow creates KeyButtons from layout definition
- Use Auto Layout or manual frame layout (manual is faster for keyboard performance)
- Keyboard height: set via `heightConstraint` on the input view — roughly 260pt (adjust for suggestion bar)

---

## Phase 3: Hold-for-Special-Characters

**Goal:** Long-press any key to show a popup with alternate characters, slide to select.

### Hold Character Mappings (Gboard-style — letter keys map to nearby numbers/symbols)
```
Q → 1    W → 2    E → 3, è, é, ê, ë    R → 4    T → 5, þ
Y → 6    U → 7, ù, ú, û, ü    I → 8, ì, í, î, ï    O → 9, ò, ó, ô, ö, ø    P → 0
A → @, à, á, â, ä, æ    S → #, ß    D → $    F → %    G → &
H → -, –    J → +    K → (    L → )
Z → *, ž    X → "    C → ', ç    V → :    B → ;    N → !, ñ    M → ?, —
```
(These can be customized. The key principle: most-used symbols on the most reachable keys.)

### Gesture Handling (KeyPressHandler)
1. On touch-down: start a 0.3s timer
2. If touch-up before timer fires → normal tap (insert primary character)
3. If timer fires while still pressed → trigger hold mode:
   - Show PopupKeyView above the held key
   - PopupKeyView displays horizontal row of alternate characters
   - Track finger drag horizontally to highlight options
4. On touch-up during hold → insert the highlighted character (or primary if finger didn't move)
5. Haptic feedback on hold trigger and on each character highlight change

### PopupKeyView
- Rendered as a UIView added to the keyboard's view hierarchy (above other keys)
- Visual: rounded rect bubble with the alternate characters laid out horizontally
- Arrow/stem pointing down to the original key
- Highlighted character has a darker/accented background
- Matches iOS stock long-press popup style (white bubble, shadow, rounded)
- Remove popup on touch-up

---

## Phase 4: Prediction Engine

**Goal:** Learn from the user's typing and suggest next words. This is the core differentiator.

### Architecture: Tri-gram Model with Recency Weighting

**NGramStore** — persistent storage using SQLite (via a lightweight wrapper or raw SQLite3 C API — avoid heavy dependencies)

Tables:
```sql
-- Unigram frequencies
CREATE TABLE unigrams (
    word TEXT PRIMARY KEY,
    frequency INTEGER DEFAULT 1,
    last_used REAL  -- timestamp
);

-- Bigram frequencies  
CREATE TABLE bigrams (
    word1 TEXT,
    word2 TEXT,
    frequency INTEGER DEFAULT 1,
    last_used REAL,
    PRIMARY KEY (word1, word2)
);

-- Trigram frequencies
CREATE TABLE trigrams (
    word1 TEXT,
    word2 TEXT,
    word3 TEXT,
    frequency INTEGER DEFAULT 1,
    last_used REAL,
    PRIMARY KEY (word1, word2, word3)
);
```

Storage location: App Group shared container so both the host app and keyboard extension can access it.

### PredictionEngine Logic

**Learning (called after each word is committed — space/punctuation pressed):**
1. Tokenize the current sentence from `textDocumentProxy.documentContextBeforeInput`
2. Extract the last 1-3 words
3. Upsert into unigrams, bigrams, trigrams tables (increment frequency, update timestamp)
4. Batch writes — buffer and flush every ~5 words to avoid I/O overhead

**Predicting (called on every keystroke and after each word):**
1. Get context: last 2 completed words from `documentContextBeforeInput`
2. Get current partial input (word being typed)
3. Score candidates:
   - If 2 context words available: query trigrams WHERE word1=ctx1 AND word2=ctx2 → candidates for word3
   - If 1 context word: query bigrams WHERE word1=ctx1 → candidates for word2
   - Fallback: query unigrams sorted by frequency
   - If partial input exists: filter all candidates by prefix match
4. Scoring formula:
   ```
   score = (trigram_freq * 3.0 + bigram_freq * 2.0 + unigram_freq * 1.0) * recency_boost
   recency_boost = 1.0 + (2.0 / (1.0 + days_since_last_used))
   ```
   This gives recently used phrases a significant but decaying boost — mimics Gboard's "temporary memory" behavior.
5. Return top 3 candidates as `[PredictionResult]`

**Autocorrect (lightweight):**
- Ship a bundled `base_dictionary.txt` (a list of ~50k common English words)
- If the typed word isn't in the dictionary OR n-gram store, compute Levenshtein distance to known words
- If distance ≤ 2 and a single clear best match exists, show it as the center (bold) suggestion
- User tapping the original typed word (shown as left suggestion) overrides and learns it

### SuggestionBarView
- Three suggestion slots: [left] [center/bold] [right]
- Center slot = best prediction or autocorrect. Left and right = alternatives.
- Tapping a suggestion: inserts the word + a space, triggers learning
- If user types a word fully and hits space (ignoring suggestions), still learn that word
- Suggestion bar height: ~44pt
- Visual: translucent background, thin top border, system font ~17pt, center suggestion slightly bolder

### Bootstrapping (Cold Start)
- On first launch, the n-gram database is empty
- Fall back to the bundled base dictionary for basic autocorrect
- Predictions improve rapidly — after ~50-100 typed messages the trigram model becomes useful
- Optionally: ship a pre-built "common English phrases" trigram seed (from public domain text) to give predictions from minute one

---

## Phase 5: Polish + Feel

### Haptics (HapticManager)
- Use `UIImpactFeedbackGenerator` with `.light` style on every key tap
- `.medium` on backspace delete
- `.rigid` on shift toggle and mode switch

### Sound
- Optional key click sound (respect system setting `UIDevice.current.isInputSwitchSoundEnabled` — note: this API doesn't exist, instead just provide a toggle in the host app)
- Use `AudioServicesPlaySystemSound` with the standard keyboard click sound ID (1104)

### Theme (ThemeManager)
- Detect `traitCollection.userInterfaceStyle` for light/dark
- Define all colors as a theme struct:
  ```swift
  struct KeyboardTheme {
      let keyBackground: UIColor
      let specialKeyBackground: UIColor
      let keyTextColor: UIColor
      let keyHighlightColor: UIColor
      let suggestionBarBackground: UIColor
      let keyboardBackground: UIColor
      let keyShadowColor: UIColor
  }
  ```
- Light theme: white keys, #D1D4D9 special keys, #F2F1F6 keyboard background
- Dark theme: #636366 keys, #4A4A4C special keys, #1C1C1E keyboard background

### Performance Notes
- Keyboard extensions have a **48MB memory limit** — exceeding it = instant kill
- SQLite is fine but keep the database pruned (cap at ~100k n-grams, evict lowest-frequency + oldest entries periodically)
- Key rendering: avoid `drawRect` — use layer properties (backgroundColor, cornerRadius, shadow) for hardware-accelerated rendering
- Prediction queries should complete in <16ms to not stall the UI — use indexed queries and limit result sets

---

## Phase 6: Host App (Setup + Settings)

### MainViewController
Simple onboarding flow:
1. "Welcome to GhostKeys" — app icon + brief description
2. Step-by-step setup instructions with screenshots:
   - Open Settings
   - General → Keyboard → Keyboards
   - Add New Keyboard → GhostKeys
   - Tap GhostKeys → Enable "Allow Full Access" (needed for the learning feature)
3. "You're all set!" confirmation

### Settings (optional, nice-to-have)
- Toggle: haptic feedback on/off
- Toggle: key click sound on/off
- Toggle: autocorrect on/off
- Button: "Clear learned data" (wipes n-gram database)
- Display: stats (words learned, total keystrokes)

---

## Build & Deployment Notes

### Xcode Configuration
- Deployment target: iOS 17.0
- Both targets must share the same **Team** (your Apple ID) and **App Group**
- Keyboard extension's `Info.plist` must have `RequestsOpenAccess = YES` for file/data access
- No third-party dependencies — use only Foundation, UIKit, SQLite3 (system library), AudioToolbox
- This keeps the binary small and avoids CocoaPods/SPM complexity

### Testing on Device
1. Open the `.xcodeproj` in Xcode
2. Select your iPhone 15 Pro as the run destination
3. Sign both targets with your Apple ID (Xcode handles free provisioning)
4. Build and run — it installs the host app
5. On the phone: Settings → General → Keyboard → Keyboards → Add → GhostKeys
6. Open any text field, tap globe icon to switch to GhostKeys

### Sideloading for Long-Term Use (No Dev Account)
1. Archive the build in Xcode → Export IPA
2. Transfer IPA to Windows PC
3. Install AltStore + AltServer on Windows
4. AltStore re-signs the IPA every 7 days automatically
5. No Mac needed again unless updating the code

---

## File Generation Order

Generate files in this order to minimize forward-reference issues:

1. `Shared/AppGroupConstants.swift`
2. `GhostKeyboard/Utilities/SharedDefaults.swift`
3. `GhostKeyboard/Utilities/ThemeManager.swift`
4. `GhostKeyboard/Utilities/HapticManager.swift`
5. `GhostKeyboard/Utilities/SoundManager.swift`
6. `GhostKeyboard/Models/KeyDefinition.swift`
7. `GhostKeyboard/Models/KeyboardState.swift`
8. `GhostKeyboard/Models/KeyboardLayout.swift`
9. `GhostKeyboard/Views/KeyButton.swift`
10. `GhostKeyboard/Views/PopupKeyView.swift`
11. `GhostKeyboard/Views/KeyRow.swift`
12. `GhostKeyboard/Views/SuggestionBarView.swift`
13. `GhostKeyboard/Views/KeyboardView.swift`
14. `GhostKeyboard/Gestures/KeyPressHandler.swift`
15. `GhostKeyboard/Gestures/HoldCharacterPicker.swift`
16. `GhostKeyboard/Prediction/PredictionResult.swift`
17. `GhostKeyboard/Prediction/NGramStore.swift`
18. `GhostKeyboard/Prediction/PersonalDictionary.swift`
19. `GhostKeyboard/Prediction/PredictionEngine.swift`
20. `GhostKeyboard/KeyboardViewController.swift`
21. `GhostKeys/AppDelegate.swift`
22. `GhostKeys/MainViewController.swift`
23. Info.plist files for both targets
24. `.xcodeproj` configuration (or generate via `xcodegen` — include a `project.yml`)

### Recommendation: Use XcodeGen
Since the local toolchain can't run Xcode, generate a `project.yml` for [XcodeGen](https://github.com/yonaskolb/XcodeGen). This lets you define the entire Xcode project in YAML — targets, build settings, entitlements, Info.plists — and generate the `.xcodeproj` with one command on the borrowed Mac:
```bash
brew install xcodegen
xcodegen generate
```
This avoids needing to manually configure Xcode project files (which are notoriously messy XML).

---

## Summary

| Phase | What it delivers | Complexity |
|-------|-----------------|------------|
| 1 | Skeleton that builds and loads as a keyboard | Low |
| 2 | Full iOS-look QWERTY that types | Medium |
| 3 | Hold-for-special-characters | Medium |
| 4 | N-gram prediction + learning | High |
| 5 | Haptics, sound, theming polish | Low |
| 6 | Host app onboarding + settings | Low |
