#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# rolemask.py: reads t.sh output (mask 0) on stdin; keeps TurnOver's own words (roles, states, counts, hints), masks the rest.
import sys, re
keep = set("""link button edit heading level list items graphic table visited row column menu bar blank with check box checked not grouping
no next previous landmark region article navigation main banner separator pop up bottom top of end new line selected unselected
document window dialog sheet alert tool text field search area message body subject to cc bcc from reply forward delete draft save
cancel ok send sent messages conversations sections compose page shelf shelves player sidebar toolbar item outline tree view
cell rows columns expanded collapsed submenu closed input help on off mode focus browse spelling error misspelled deleted
space presses it return opens tab moves goes shift escape back home arrow keys move between the choices and or a an this that
you your in for is are at by goes press hint play playing paused stopped loading unavailable required read only
first last one two three four five six seven eight nine ten percent point bold italic underlined plain""".split())
for l in sys.stdin:
    if 'say:' in l:
        head, t = l.split('say:', 1)
        t = re.sub(r"[A-Za-z][A-Za-z'’]*", lambda m: m.group(0) if m.group(0).lower() in keep else m.group(0)[0] + '…', t)
        print((head.split(']')[0] + '] say:' + t).rstrip()[:130])
    elif 'input kb' in l or 'FAIL' in l or 'ACTIVE' in l or 'FRONT' in l:
        print(l.rstrip()[:110])
