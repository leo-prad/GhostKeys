# GhostKeys — Testing Feedback Punch List

Based on first real device test. Organized by category, roughly in priority order (broken functionality first, then polish, then new features).

---

## 🔴 Broken / High Priority

1. **Hit-testing too strict** — pressing between letters (dead zones) registers no keypress at all. Needs larger effective touch targets per key (touch area should extend into the gaps, not just the visible key rect), or a nearest-key fallback based on x/y distance.

2. **Long-press for alternate characters is inconsistent** — edge keys (Q, P) require a noticeably longer hold than center keys to trigger the popup. Long-press timer/threshold should be uniform across all keys — audit for per-key timing differences or touch-area-size-dependent triggering.

3. **Character preview (key pop-up on tap) is clipped** — likely getting cut off by keyboard view bounds, especially at edges. Preview view needs to stay within screen bounds (shift inward when near edges) and not currently isn't working at all for edge letters/symbols.

4. **Autocorrect is actively harmful** — e.g. "doesnt" → "doesn" is a regression, not a correction. Needs a real audit of the edit-distance/scoring logic — likely a bug causing truncation rather than correction. This should be tested against a wordlist before shipping again.

5. **Space bar doesn't auto-return to letters page after typing symbol** — on the numbers/symbols page, typing a character then hitting space should auto-switch back to the letters page (matches iOS stock behavior). Currently stays on symbols page.

6. **No space auto-insert after glide typing** — after a glide-typed word, the next typed letter/word should get an automatic space before it, same as tap-typing. Currently missing.

---

## 🟡 Glide Typing — Needs Rework

7. **Detection accuracy is poor** — the path-to-word matching algorithm needs real tuning/rework. This is likely the single biggest lift on this list.

8. **No live word preview during glide** — as the finger moves, the suggestion bar (or a floating preview) should continuously show the best-guess word in progress, updating in real time, not just revealing it after lift-off.

9. **Trail rendering is wrong** — currently a solid line of constant width. Needs:
   - Variable width: thick near the current finger position, tapering to a thin point at the tail
   - Fade-out gradient/opacity along the trail (older points more transparent)
   - Shortened max trail length — should not persist the entire glide path, only a recent window

10. **Glide typing doesn't respect caps lock** — if caps lock is active, glide-typed output should be inserted as uppercase. Currently always lowercase regardless of state.

---

## 🟢 Missing Standard iOS Keyboard Behaviors

11. **Hold-spacebar-to-move-cursor** — long-pressing the space bar should convert it into a cursor-drag trackpad (standard iOS behavior). Not implemented at all currently.

12. **Swipe-left-on-backspace to delete words** — swiping left from the backspace key should enter a "delete mode" highlighting/selecting words as you drag, deleting them on release. Currently backspace only supports tap/hold-repeat.

---

## 🔵 Visual Polish

13. **Suggestion bar alignment** — the three suggestion words need proper centering within their respective thirds of the suggestion bar (left/center/right zones).

14. **Key spacing and sizing** — increase spacing between keys and adjust overall key sizing — likely ties into fixing the hit-testing issue in item #1 (bigger visual keys + bigger touch targets solves two problems at once).

14a. **Keys should be very slightly slimmer, with slightly more padding between them** — a small reduction in individual key width combined with a bit more horizontal gap between keys. Subtle adjustment, not a major resize.

15. **Caps lock key state is not visually indicated** — the shift/caps key should visually change (e.g. filled/highlighted background) when caps lock is engaged. Currently stays flat white regardless of shift state.

16. **Suggestions don't reflect caps lock state** — when caps lock is on, suggested words in the suggestion bar should render in all-caps to match what will actually be inserted. Currently always shows lowercase suggestions regardless of keyboard state.

---

## ✨ New Feature Request

17. **Case-matching text replacement** — if a user has a text replacement/shortcut set (e.g. "brb" → "Be Right Back!"), typing it in all-caps ("BRB") should expand to the all-caps version of the replacement ("BE RIGHT BACK!"), not the originally-saved case. Needs a settings toggle in the host app to enable/disable this behavior, since not everyone will want it.

---

## Suggested Build Order

Given the dependencies between these:

1. Fix hit-testing (#1) + key sizing (#14) together — same root cause area
2. Fix long-press timing consistency (#2) + character preview clipping (#3) — same gesture/rendering system
3. Fix autocorrect regression (#4) — isolated, testable against wordlist
4. Fix symbols-page auto-return (#5) + glide auto-space (#6) — quick, isolated fixes
5. Caps lock visual + suggestion case-matching (#10, #13, #15, #16) — all tie into a single "keyboard state → rendering" pass
6. Glide typing rework (#7, #8, #9) — biggest chunk, tackle as its own phase
7. New gesture behaviors: hold-space-cursor (#11), swipe-backspace-delete (#12)
8. Text replacement case-matching feature (#17) — net new, do last
