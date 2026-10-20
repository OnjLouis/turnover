# The plans

The design documents behind the code: each was written before its feature was built and says why it is the way it
is. The code's comments point here ("docs/MENU-PLAN.md"). The files at the root (README, ARCHITECTURE, TESTING,
PATTERNS, PLUGIN-GUIDE, PUBLIC-ROADMAP, CHANGELOG) are the ones to read first; these are the detail.

| File | What it is |
|---|---|
| `APP-RECIPES-PLAN.md` | Apps described by data, not code: recipes (`Resources/recipes/*.json`), the parts a recipe can name, and the tool that drafts one. |
| `BRAILLE-PLAN.md` | Braille displays: the Mac's own drivers reached from Objective-C, the tables, typing, and VoiceOver's chords. |
| `KEYBOARD-STYLES-PLAN.md` | The keyboard styles (VoiceOver, NVDA, Narrator and JAWS keys) everywhere on the Mac, whichever reader is speaking, and how clashes with Mac shortcuts are settled. |
| `MENU-PLAN.md` | The TurnOver menu (Command Control Comma, M): "This app" first, names in titles and explanations after, hand over and quit in one place. |
| `PLUGIN-TOOLKIT-PLAN.md` | The plugin toolkit: the hand-written format, the maker in the app, `--explain`, and the tests that travel with a plugin. Parked in parts; the later design notes override it where they differ. |
| `TOC-PREFERENCES.md` | Every setting comes from VoiceOver: the map from VoiceOver Utility's export to TurnOver's settings, and what has no VoiceOver counterpart. |
| `VOICEOVER-PARITY.md` | The VoiceOver keys: every VoiceOver command, what answers it in TurnOver, and the rulings on the ones that differ. |
| `NVDA-PARITY.md` | The NVDA keys: every NVDA command, what answers it in TurnOver, and the variations put to the maintainer. |

`archive/` holds plans that are finished or superseded, kept as they were.
