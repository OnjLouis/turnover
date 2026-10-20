> Archived 16 Oct 2026: history from the Bosun days, kept as it was. What it planned is either done, in the roadmap, or dropped; the code is the reference now.

# Word: what VoiceOver users complain about, and where TurnOver stands

From AppleVis, 4 Oct 2026: the thread "Microsoft Word and Voiceover, whats the deal?" and 22 other threads from 2022
on, plus Microsoft's own Word-for-Mac screen reader pages. The aim: TurnOver's Word must be significantly
better than VoiceOver's to be worth having.

Status: **Done** (built and used), **Partly**, **Not yet**, **Untested** (built, never tried on the case).

## The complaints, most reported first

| Complaint (people, latest) | TurnOver now | To do |
|---|---|---|
| Up/Down or VO+L reads the whole document from the top (about 12, Aug 2025; comes and goes with Word updates) | Done: TurnOver reads lines through its own text model, not VoiceOver's | Keep a regression test per Word update |
| Large documents (20 to 200+ pages): Word "not responding", VoiceOver stuck while the caret moves (6+, Sep 2026) | Untested: TurnOver's main thread no longer waits on Word (E6), and a stuck app is left alone (E12) | Test on an 85-page and a 200-page document; time line, page and heading moves |
| Comments: cannot read the comment, go to next/previous, or edit the comment field (5+, Aug 2025) | Partly: next/previous comment (TO+M), read comment at caret (TO+Option+C), comments in the Rotor (VO+U) | Say "comment" while arrowing over commented text; make the comment pane's field readable and editable; a key to add a comment |
| Track changes: cannot move between, accept or reject; "annotation, insertion change" before every word (several, Nov 2024) | Partly: next/previous change (TO+R), toggle tracking with its state said (Command+Shift+E) | Say the change once (type and author) as the caret enters it, not on every word; accept and reject keys; changes in the Rotor |
| Tables silent; Tab selects the whole cell so typing replaces it; large tables confuse the VO cursor (3+, Sep 2026) | Done (4 Oct 2026), read from Word's own accessible table, no AppleScript: entering says "table with 6 rows and 2 columns, row 1, column 1" and the text; moves say only what changed, with the column title (first row) and row title (first column); "blank" for empty cells; "selected" after Tab; TO+arrows go cell to cell without selecting; "edge of table"; "out of table" and the line on leaving | Merged cells untested; a Rotor list of tables |
| Heading navigation does not work (3, Jun 2024) | Done: next/previous heading (TO+H, Shift), headings in the Rotor | — |
| Echo slow while typing fast (1, Jun 2024) | Done: interrupting echo, field-based word echo (4 Oct 2026) | — |
| Option+Arrow word movement slow, joins fragments (3, Mar 2025) | Untested: TurnOver's own word unit | Test in Word |
| Caret jumps to page 1 after Command+Tab out and back (1, Mar 2025) | Untested | Test; if Word moves it, restore the position TurnOver saw last |
| Only Print Layout works (3, Jun 2024) | Untested in Draft and Web Layout | Test; say which view when it matters |
| Selected text not spoken (2, Dec 2024) | Done in general (selection changes are read); untested in Word | Test Shift+arrows and Command+A |
| VO+Shift+C (copy last spoken) fails in Word (Nov 2024) | Done: TurnOver's copy-last-spoken works everywhere | — |
| No confirmation when applying formatting (Apr 2023) | Done: bold, italic, underline, size, alignment, spacing, styles and track changes each say their new state | — |
| Spelling: no quick way to the next error, or its suggestions | Partly: next/previous misspelling (TO+E) | Read the suggestions for the word at the caret |
| Page, line and column on demand (NVDA users miss it) | Partly: page and line (TO+Delete, asynchronous since 4 Oct) | Add the column |

## What NVDA users on Windows say they miss (the bar to clear)

- An elements list of comments, revisions, spelling errors, footnotes and bookmarks: TurnOver's Word Rotor has
  headings and comments; add revisions, spelling errors and footnotes.
- Comments announced while reading, and a key to read one: partly (the key exists).
- Table commands by row, column and cell: done (TO+arrows).
- Line, column and page on a key: page and line yes, column not yet.
- Formatting changes confirmed as applied: done.
- Undelayed character echo: done.

## Order of work (proposed)

1. **Tables**: the most painful for real work (legal forms, coursework).
2. **Track changes and comments**: the biggest blocker for anyone working with an editor or tutor.
3. **Long-document test pass**: time the moves, fix what stalls.
4. **The Word Rotor**: revisions, spelling errors, footnotes; spelling suggestions; column on TO+Delete.
5. **The untested rows**: word movement, Command+Tab return, other views, selection.

Sources: the AppleVis threads listed in the survey of 4 Oct 2026 (session transcript); Microsoft's pages on using a
screen reader with Word for Mac (tracking changes; exploring and navigating).
