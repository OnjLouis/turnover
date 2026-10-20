#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Split a big Swift class file into the class and extensions in files of their own (8 Oct 2026, from the team
review). Methods in each named range go to a new file as `extension <Class> { … }`; stored instance properties in
those ranges are hoisted back into the class (extensions cannot hold them); `private` becomes internal in the
class and its extensions, since the pieces now live in several files of one module.

Usage: split-class.py <file> <Class> <classStart-classEnd> <title>=<start-end>=<NewFile.swift> …
Line numbers are 1-based and inclusive. The header (file comment and imports) is copied to each new file.
"""
import re, sys, os

path, cls, class_range = sys.argv[1], sys.argv[2], sys.argv[3]
cs, ce = map(int, class_range.split("-"))
parts = []
for a in sys.argv[4:]:
    title, rng, out = a.split("=")
    s, e = map(int, rng.split("-"))
    parts.append((title, s, e, out))
lines = open(path).read().split("\n")
# The header: everything up to the first import line's block end.
hdr_end = max(i for i, l in enumerate(lines) if l.startswith("import ")) + 1
header = lines[:hdr_end]

stored = re.compile(r'^    (?:(?:public|private|fileprivate|internal|open|static|weak|lazy|unowned|final)\s+)*(?:private\(set\)\s+)?(var|let)\s+\w+\s*(?::[^={]+)?(?:=.*)?$')
def is_stored_instance(l):
    if not stored.match(l): return False
    if "{" in l: return False           # computed, or has a didSet on the same line
    if re.match(r'^    (?:\w+\s+)*static\s', l): return False   # a static can live in an extension
    return True

def deprivate(l):
    l = re.sub(r'\bprivate\(set\)\s+', 'internal(set) ', l)
    l = re.sub(r'\bfileprivate\s+', '', l)
    l = re.sub(r'\bprivate\s+', '', l)
    return l

moved = set()
hoisted = []
new_files = []
for title, s, e, out in parts:
    body = []
    i = s - 1
    while i < e:
        l = lines[i]
        # A stored property (with its doc comment just above) goes back to the class.
        if is_stored_instance(l):
            j = len(body)
            while j > 0 and body[j - 1].lstrip().startswith("///"): j -= 1
            hoisted += body[j:] + [l]
            body = body[:j]
            # A multi-line initial value (a dictionary literal) is not handled: keep it simple.
            i += 1
            continue
        # A didSet/willSet property: stored too. Detect `var x = … {` followed by didSet.
        if stored.match(l.split("{")[0].rstrip()) and l.rstrip().endswith("{") and i + 1 < e and lines[i + 1].strip().startswith(("didSet", "willSet")):
            depth = 0; k = i
            while k < e:
                depth += lines[k].count("{") - lines[k].count("}")
                k += 1
                if depth == 0: break
            j = len(body)
            while j > 0 and body[j - 1].lstrip().startswith("///"): j -= 1
            hoisted += body[j:] + lines[i:k]
            body = body[:j]
            i = k
            continue
        body.append(l)
        i += 1
    for k in range(s - 1, e): moved.add(k)
    text = header + ["", "// " + title, "extension %s {" % cls] + [deprivate(x) for x in body] + ["}", ""]
    new_files.append((out, "\n".join(text)))

# The class file: everything not moved, hoisted properties before the class's closing brace.
out = []
for i, l in enumerate(lines):
    if i in moved: continue
    if i == ce - 1:   # the closing brace of the class
        if hoisted:
            out.append("")
            out.append("    // Stored properties of the parts in the other files (an extension cannot hold them).")
            out += hoisted
    out.append(l)
# Drop runs of blank lines left by the moves.
cleaned = []
for l in out:
    if l.strip() == "" and cleaned and cleaned[-1].strip() == "": continue
    cleaned.append(l)
open(path, "w").write("\n".join(deprivate(x) for x in cleaned))
d = os.path.dirname(path)
for name, text in new_files:
    open(os.path.join(d, name), "w").write(text)
    print("wrote", name)
print("kept", path, "hoisted", len([h for h in hoisted if is_stored_instance(h)]), "properties")
