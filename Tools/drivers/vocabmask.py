#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# vocabmask: TurnOver's speech with the user's content masked. Words TurnOver itself says (roles, states, positions,
# its own messages) are kept; every other word becomes "x", numbers are kept. So a readout shows the shape of what
# was said ("x x, button, 3 of 12"; a lone "button" is an unnamed one) without anyone's events, contacts or notes.
import re, sys
KEEP = set("""
a an and of the to in on at by for with from not no yes on off
button buttons heading level list item items table row rows column columns cell cells outline group grouping window
tool bar toolbar menu menus tab tabs pop up popup check box checkbox radio link graphic image picture edit text field
search slider value percent disclosure triangle split scroll area sidebar dialog sheet alert selected unselected
checked unchecked expanded collapsed dimmed unavailable required read only blank empty nothing focus mode browse
document web page landmark region banner navigation main complementary article section separator splitter progress
indicator busy loading please wait switch toggle combo stepper incrementor date time calendar day week month year
today grid collection view views title help hint first last next previous more less new add remove delete done cancel
ok close open save edit share settings general sound display keyboard network wifi bluetooth back forward
tick ticked unticked level sorted ascending descending header footer label labelled unnamed no name
press space return escape tab arrow up down left right home end option command control shift caps turnover say steps ms back out in
""".split())
def mask(line):
    out = []
    for tok in re.split(r"(\W+)", line):
        if not tok or re.fullmatch(r"\W+", tok) or tok.isdigit() or tok.lower() in KEEP: out.append(tok)
        else: out.append("x")
    return re.sub(r"(x(?:\s+x)+)", lambda m: "x…", "".join(out))
for l in sys.stdin: print(mask(l.rstrip("\n")))
