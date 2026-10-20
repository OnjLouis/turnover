#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""The guide (Resources/TurnOver Guide.txt, made from Guides/ by make-guides.py) as a web page for the download site: section titles become
headings, key lists become lists, so a screen reader can move by heading and by item. The release tooling runs it on publish.
Usage: make-guide.py <guide.txt> <guide.html>"""
import html, re, sys

src, out = sys.argv[1], sys.argv[2]
lines = open(src, encoding="utf-8").read().splitlines()
body, para, items, numbered = [], [], [], []
first_heading = True

def flush():
    global para, items, numbered
    if para: body.append("<p>" + html.escape(" ".join(para)) + "</p>"); para = []
    if items: body.append("<ul>\n" + "\n".join(items) + "\n</ul>"); items = []
    if numbered: body.append("<ol>\n" + "\n".join("<li>" + html.escape(n) + "</li>" for n in numbered) + "\n</ol>"); numbered = []

def is_heading(t):
    return len(t) > 3 and t == t.upper() and re.search(r"[A-Z]", t) is not None

for raw in lines:
    t = raw.strip()
    if not t: flush(); continue
    if is_heading(t):
        flush()
        tag = "h1" if first_heading else "h2"
        first_heading = False
        if tag == "h1": title = "TurnOver beta guide"
        else:
            title = t.capitalize()
            for name in ["TurnOver", "Mail", "Safari", "Terminal", "Microsoft", "Word", "VoiceOver"]:
                title = re.sub(rf"\b{name.lower()}\b", name, title)
        body.append(f"<{tag}>{html.escape(title)}</{tag}>")
        continue
    m = re.match(r"^(\d+)\.\s+(.*)$", t)
    if m and not raw.startswith("  "):
        if para or items: flush()
        numbered.append(m.group(2)); continue
    if raw.startswith("   ") and numbered and not re.match(r"^\s{2}\S.*\s{2,}\S", raw):
        numbered[-1] += " " + t; continue
    if raw.startswith("  "):
        k = re.match(r"^\s{2,}(\S.*?)\s{2,}(\S.*)$", raw)
        if k and len(raw) - len(raw.lstrip()) < 6:
            if para: body.append("<p>" + html.escape(" ".join(para)) + "</p>"); para = []
            items.append(f"<li><strong>{html.escape(k.group(1))}</strong>: {html.escape(k.group(2))}</li>"); continue
        if items:   # a continuation of the item above
            items[-1] = items[-1][:-5] + " " + html.escape(t) + "</li>"; continue
    if items: flush()
    para.append(t)
flush()

page = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow"><title>TurnOver beta guide</title>
<style>body{{font:1rem/1.5 -apple-system,system-ui,sans-serif;max-width:46rem;margin:0 auto;padding:1rem;color:#111;background:#fff}}
@media (prefers-color-scheme:dark){{body{{color:#eee;background:#111}}a{{color:#8ab4ff}}}}</style></head>
<body><main>
{chr(10).join(body)}
<p><a href=".">Back to the download page</a></p>
</main></body></html>
"""
open(out, "w", encoding="utf-8").write(page)
