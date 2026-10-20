# SPDX-License-Identifier: GPL-3.0-or-later
# Masks words that aren't common interface words: "Kitchen" -> "K6". In snapshot lines (key="value") only the
# quoted values are masked; in "says:" lines every word.
import re, sys
UI = set("""says not found button buttons list row rows column table cell group toolbar window dialog sheet alert menu
item items bar tab tabs selected checked unchecked unselected dimmed text field edit image link heading level
search scroll area slider value of on off new done cancel ok open close play pause record stop delete share more
settings options edit view help back forward next previous all none add remove with the a an and or in to for
from by at is no yes recordings recording voice memos home rooms room scenes accessories favourites favorites
library sidebar collapsed expanded outline popup pop up combo box checkbox radio switch toggle disclosure triangle
navigation title untitled clicked pressed focused empty content contents application app file files folder
general preferences save quit archived chats calls updates communities starred lists favourites unread groups about window minimise minimize zoom full screen show hide new tab
""".split())
def mask(w):
    if w.lower().strip(",.:;()\"'") in UI or not re.search(r"[A-Za-z]", w): return re.sub(r"\d", "#", w)
    return w[0] + str(len(w) - 1)
def masktext(s): return " ".join(mask(w) for w in s.split(" "))
for line in sys.stdin:
    line = line.rstrip("\n")
    if re.match(r"\s*AX", line): print(re.sub(r'="([^"]*)"', lambda m: '="' + masktext(m.group(1)) + '"', line))
    elif "says:" in line: print(masktext(line))
    else: print(line)
