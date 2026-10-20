#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""The public roadmap (PUBLIC-ROADMAP.md, private here) as a plain, screen-reader-friendly page for the updates site:
headings stay headings, bullets stay a list. python3 make-roadmap.py PUBLIC-ROADMAP.md out.html"""
import html, re, sys

src, out = sys.argv[1], sys.argv[2]
lines = open(src, encoding="utf-8").read().splitlines()

def inline(t):
    t = html.escape(t, quote=False)
    t = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', t)
    return t

body, para, items, title = [], [], [], "What's coming to TurnOver"
def flush_para():
    if para: body.append("<p>" + inline(" ".join(para)) + "</p>"); para.clear()
def flush_items():
    if items: body.append("<ul>\n" + "\n".join("<li>" + inline(i) + "</li>" for i in items) + "\n</ul>"); items.clear()

for raw in lines:
    line = raw.rstrip()
    if not line.strip():
        flush_para(); flush_items(); continue
    m = re.match(r"^(#{1,3}) (.*)", line)
    if m:
        flush_para(); flush_items()
        level = len(m.group(1))
        if level == 1: title = m.group(2)
        body.append(f"<h{level}>{inline(m.group(2))}</h{level}>"); continue
    if line.startswith("- "):
        flush_para(); items.append(line[2:].strip()); continue
    if items and raw.startswith("  "):
        items[-1] += " " + line.strip(); continue
    flush_items(); para.append(line.strip())
flush_para(); flush_items()

open(out, "w", encoding="utf-8").write(f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow"><title>{html.escape(title)}</title></head>
<body><main>
{chr(10).join(body)}
<p><a href="index.html">TurnOver beta home</a></p>
</main></body></html>
""")
