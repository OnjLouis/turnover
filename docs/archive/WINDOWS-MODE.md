> Archived 16 Oct 2026: history from the Bosun days, kept as it was. What it planned is either done, in the roadmap, or dropped; the code is the reference now.

# Windows keyboard style (6 Oct 2026)

The aim: in the Mac style TurnOver works like VoiceOver, with the same key presses. In the Windows style the Mac should
feel like a Windows machine running NVDA. Switch with TurnOver Shift K, or in the TurnOver menu (Keyboard style, at
the top level and in Preferences, Keyboard). Mac is the default.

A Mac keyboard has the keys in different places. The PC's Alt sits where the Mac's Command is (beside the space bar),
and the PC's Control is at the far left, as the Mac's Control is. So a Windows user's thumb presses Command for Alt,
and their little finger presses Control for Control. The Windows style translates by position.

Status: **done** (in the code now), **next** (to build). The whole-Mac layer was built, then shelved (6 Oct 2026):
where VoiceOver leads the keys are the Mac's. The code stays in WindowsKeys.swift (WindowsKeyLayer), unused.

## System

| Windows | What it does | On the Mac in Windows style | Status |
|---|---|---|---|
| Alt, or F10 | Menu bar | Command alone, or F10 | done |
| Windows key | Start | Left Option alone: the Dock. (Spotlight, Command Space, is the nearer match for "type to find"; still to choose) | done (Dock) |
| Applications key, Shift F10 | Context menu | Right Option alone; Shift F10 | done; Shift F10 next |
| Alt Tab | Switch app | Command Tab (already where Alt is) | works |
| Alt F4 | Close the app | Command F4 (Command Q) | done |
| Control F4, Control W | Close window or tab | Control F4 (Command W); Control W (Command W) | done |
| Windows B | Notification area | Option B: the status menus | done |
| Windows D | Desktop | Option D: show desktop | next |
| Windows E | File Explorer | Option E: a Finder window | next |
| Windows R, Windows S | Run, search | Option R, Option S: Spotlight | next |
| Windows L | Lock | Option L: Control Command Q | next |
| Windows A, Windows N | Quick settings, notifications | Option A: Control Centre; Option N: Notification Centre | next |
| Windows I | Settings | Option I: System Settings | next |
| Windows M | Minimise all | Option M: Command Option M in the front app | next |
| Windows period | Emoji | Option period: Control Command Space | next |
| F1 to F12 | Function keys | F1 to F12 while TurnOver leads (media keys back when VoiceOver does) | done |

## Editing text

| Windows | What it does | Sent to the Mac app as | Status |
|---|---|---|---|
| Control C, X, V, A, Z | Copy, cut, paste, select all, undo | Command C, X, V, A, Z | done |
| Control Y | Redo | Command Shift Z | done |
| Control S, O, N, P, F | Save, open, new, print, find | Command S, O, N, P, F | done |
| Home, End | Start, end of line | Command Left, Command Right | done |
| Control Home, Control End | Start, end of document | Command Up, Command Down | done |
| Control Left, Control Right | Word by word | Option Left, Option Right | done |
| Control Up, Control Down | Paragraph by paragraph | Option Up, Option Down | done |
| Control Backspace, Control Delete | Delete a word | Option Backspace, Option Delete | done |
| Shift with any of these | Select | Shift with the Mac key | done |

Not in Terminal: there Control C, Control D and the rest are the shell's, and pass untouched. Each app module can opt
out (Word has its own Windows-like keys already).

## File Explorer, in Finder

| Windows | What it does | Sent to Finder as | Status |
|---|---|---|---|
| Enter | Open | Command Down | done |
| F2 (or Shift Enter) | Rename | Return | done |
| Backspace, Alt Up | Up a folder | Command Up | next |
| Alt Left, Alt Right | Back, forward | Command [ and Command ] | next |
| Delete | To the Bin | Command Backspace | next |
| Control Shift N | New folder | Command Shift N | next |
| Alt Enter | Properties | Command I | next |
| Control A, C, X, V | Select all, copy, cut, paste | Command A, C, X (then Command Option V to move), V | next |

Shift Delete (delete for good) is left out on purpose.

## Browsers, in Safari

| Windows | What it does | Sent to Safari as | Status |
|---|---|---|---|
| Control L, Alt D, F6 | Address bar | Command L | next |
| Control T, Control W, Control Tab | New tab, close tab, next tab | Command T, Command W, Control Tab | next |
| F5, Control R | Reload | Command R | next |
| Alt Left, Alt Right, Backspace | Back, forward | Command [ and Command ] | next |
| Control D, Control H, Control J | Bookmark, history, downloads | Command D, Command Y, Command Option L | next |
| Control plus, minus, zero | Zoom | Command plus, minus, zero | next |

## NVDA's own keys

TurnOver's commands follow NVDA's (the TurnOver key is NVDA's key), with NVDA's laptop and desktop layouts
(Preferences, Keyboard, Keyboard layout). In the Mac style the TurnOver key also takes VoiceOver's commands, and where
the two clash VoiceOver's wins. In the Windows style VoiceOver's are switched off (VoiceOverKeysPlugin is Mac-style
only, already), so NVDA's apply. The clashes today:

| Key | Windows style (NVDA) | Mac style (VoiceOver) |
|---|---|---|
| TurnOver T | Title | Text attributes (VO T) |
| TurnOver F7 | Elements list | Date and time (VO F7) |
| TurnOver S | Speech mode | Sentence (VO S) |
| TurnOver Q | Quit TurnOver | Quick Nav (VO Q) |
| TurnOver Tab | Says the focus | Passes the next key (VO Tab) |

Missing NVDA commands to add for the Windows style: NVDA B (read the window), NVDA Shift B (battery), NVDA Control F
(find, in browse mode), NVDA F12 twice (date).

## Where it applies: only where TurnOver leads, or everywhere (6 Oct 2026)

A setting beside the style: "Windows keys: only where TurnOver leads / everywhere".
- Only where TurnOver leads: as built today.
- Everywhere: a small key layer stays on while VoiceOver leads too, and translates the Windows keys that are about the
  Mac rather than about reading: the editing keys (Control C to Command C, Home and End, Control with the arrows), the
  system ones (Command alone for the menus, Option alone for the Dock or Spotlight, Command F4, the Option family), and
  Finder's Enter and F2. VoiceOver reads the result as usual.
- What cannot come along where VoiceOver leads: TurnOver's own reading commands (NVDA's T, F7, browse mode keys),
  because VoiceOver is the reader there. Those stay VoiceOver's.
- Rules for the layer: anything with Control and Option together, or Caps Lock, passes untouched (VoiceOver's
  keys); Terminal keeps Control; text being typed is never touched. It needs no new permission (TurnOver already
  has Input Monitoring and Accessibility).
- To check first: that VoiceOver acts on keys rewritten by TurnOver's tap as on typed ones (the hand-over already posts
  VoiceOver's own shortcut and it works).

## Order of work
1. Done (build 11): the editing remap (Control for Command, Home and End, Control with the arrows): the biggest win, everywhere
   TurnOver leads, Terminal excepted.
2. Explorer and browser keys in Finder and Safari.
3. The Windows key family on Option.
4. Shelved (6 Oct 2026): the same layer where VoiceOver leads. Built, switched off, no menu item.
