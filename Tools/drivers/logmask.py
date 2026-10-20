# SPDX-License-Identifier: GPL-3.0-or-later
# Log lines with every spoken word hidden: "say:" keeps only a trailing "N of M" (or a few known UI words).
import re, sys
KEEP = {"sections", "conversations", "messages", "no messages", "no conversations", "sent", "blank"}
for line in sys.stdin:
    line = line.rstrip("\n")
    m = re.match(r"(.*?\bsay: )(.*)$", line)
    if m:
        body = m.group(2)
        pos = re.search(r"(\d+ of \d+)$", body)
        line = m.group(1) + (body if body in KEEP else ("… " + pos.group(1) if pos else "(text)"))
    print(line)
