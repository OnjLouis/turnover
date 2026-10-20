#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# maskedlog.py <logfile> <from-line>: TurnOver's log from a line on, with spoken words masked (letters → x), for
# testing in private apps (Messages, WhatsApp, Mail) without reading their content.
import sys, re
lines = open(sys.argv[1], errors="replace").read().splitlines()[int(sys.argv[2]) - 1:]
for l in lines:
    if not re.search(r"input kb|say:|chat:|gainFocus|menu", l): continue
    m = re.search(r"(say: |gainFocus: \S+ )(.*)", l)
    if m: l = l[:m.start()] + m.group(1) + re.sub(r"[A-Za-z]+", "x", m.group(2))[:90]
    print(l[:150])
