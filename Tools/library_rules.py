#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""The rules a plugin submission must meet before TurnOver's plugin library takes it.

Used twice: by the GitHub check on every pull request (quick feedback, in plain words), and by the library steward
on TurnOver's own Mac, which is the authority: it fetches the files itself, applies these rules again, runs
TurnOver's full plugin check, and only then merges. Nothing here runs a submission's files; they are only read.

The rules:
- One plugin per submission: every changed file is inside plugins/<id>/, and nothing else in the repository changes.
- Only plugin files: manifest.json, profile.json, and tests/<name>.json; each at most 1 MB, plain UTF-8 text.
- The manifest names the folder: its id is the folder's name.
- A plugin is updated only by the person who first submitted it (authors.json). Official plugins only by TurnOver.
- One plugin per app: a new plugin may not claim an app another plugin already has.
- A withdrawn plugin's id is never reused.
- "provides" (switching on a feature built into TurnOver) is for official plugins only.
"""
import json
import re
import sys

ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9-]{0,63}$")
TEST_RE = re.compile(r"^tests/[A-Za-z0-9][A-Za-z0-9._-]{0,63}\.json$")
BUNDLE_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9.-]{0,254}$")
MAX_BYTES = 1_000_000
OFFICIAL_OWNER = "TurnOver-For-Mac"


def loads_relaxed(text):
    """JSON as TurnOver reads it: // and /* */ comments and trailing commas allowed."""
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1]); i += 2; continue
            if c == '"':
                in_str = False
            i += 1; continue
        if c == '"':
            in_str = True; out.append(c); i += 1; continue
        if text.startswith("//", i):
            j = text.find("\n", i); i = n if j < 0 else j; continue
        if text.startswith("/*", i):
            j = text.find("*/", i + 2); i = n if j < 0 else j + 2; continue
        out.append(c); i += 1
    cleaned = "".join(out)
    # Trailing commas, outside strings (strings were kept whole above, so a comma before } or ] here is structural).
    cleaned = re.sub(r",(\s*[}\]])", r"\1", cleaned)
    return json.loads(cleaned)


def check_submission(changes, read, author, library):
    """changes: [(path, status)] with status "added", "modified", "removed" or "renamed" (GitHub's words).
    read(path) -> bytes of the submitted file (None if missing). author: the GitHub login of the pull request.
    library: {"authors": {id: login}, "levels": {id: level}, "withdrawn": set(ids), "apps": {id: [bundle ids]}}.
    Returns (ok, problems, plugin_id, is_new)."""
    problems = []
    if not changes:
        return False, ["The pull request changes no files."], None, False
    ids = set()
    for path, status in changes:
        parts = path.split("/")
        if len(parts) < 3 or parts[0] != "plugins" or any(p in ("", ".", "..") or p.startswith(".") for p in parts):
            problems.append(f"{path}: only files inside plugins/<your plugin's id>/ can be submitted.")
            continue
        ids.add(parts[1])
        inner = "/".join(parts[2:])
        if inner not in ("manifest.json", "profile.json") and not TEST_RE.match(inner):
            problems.append(f"{path}: a plugin holds manifest.json, profile.json and tests/<name>.json only.")
        if status == "renamed":
            problems.append(f"{path}: renaming files isn't accepted; add and remove them instead.")
        if status == "removed" and inner in ("manifest.json", "profile.json"):
            problems.append(f"{path}: to take a plugin out of the library, open an issue asking for it to be withdrawn.")
    if len(ids) > 1:
        problems.append("One plugin per pull request: this one changes " + ", ".join(sorted(ids)) + ".")
    if problems:
        return False, problems, None, False
    pid = ids.pop()
    if not ID_RE.match(pid):
        return False, [f"plugins/{pid}: an id is 1 to 64 letters, digits and hyphens, starting with a letter or digit."], pid, False
    is_new = pid not in library["authors"]

    # Each file: size and text.
    for path, status in changes:
        if status == "removed":
            continue
        data = read(path)
        if data is None:
            problems.append(f"{path}: couldn't be read."); continue
        if len(data) > MAX_BYTES:
            problems.append(f"{path}: {len(data)} bytes; the most is {MAX_BYTES}.")
        try:
            loads_relaxed(data.decode("utf-8"))
        except (UnicodeDecodeError, ValueError) as e:
            problems.append(f"{path}: not readable JSON ({e}).")
    if problems:
        return False, problems, pid, is_new

    # Who may change it.
    owner = library["authors"].get(pid)
    level = library["levels"].get(pid, "Community")
    if level == "Official" or (owner or "").lower() == OFFICIAL_OWNER.lower():
        return False, [f"{pid} is an official TurnOver plugin; suggest changes in an issue instead."], pid, is_new
    if owner and owner.lower() != author.lower():
        return False, [f"{pid} is looked after by {owner}. Ask them to make the change, or open an issue."], pid, is_new
    if is_new and pid in library["withdrawn"]:
        return False, [f"{pid} was withdrawn from the library and its id can't be used again: choose another."], pid, is_new

    # The manifest, as submitted (or as it is now, for a change that leaves it alone).
    mpath = f"plugins/{pid}/manifest.json"
    raw = read(mpath)
    if raw is None:
        return False, [f"{mpath}: a plugin needs a manifest."], pid, is_new
    m = loads_relaxed(raw.decode("utf-8"))
    if not isinstance(m, dict):
        return False, [f"{mpath}: should be an object."], pid, is_new
    if m.get("id") != pid:
        problems.append(f"{mpath}: its id is {m.get('id')!r}, but the folder is {pid!r}; they must match.")
    apps = m.get("apps")
    if not isinstance(apps, list) or not apps or not all(isinstance(a, str) and BUNDLE_RE.match(a) for a in apps):
        problems.append(f"{mpath}: apps should list the bundle identifiers of the apps it works in.")
        apps = []
    if "provides" in m:
        problems.append(f"{mpath}: provides is for official TurnOver plugins only.")
    for other, other_apps in library["apps"].items():
        if other == pid:
            continue
        clash = sorted(set(apps) & set(other_apps))
        if clash:
            who = library["authors"].get(other, "its maker")
            problems.append(f"{', '.join(clash)} already has a plugin, {other}, looked after by {who}. One plugin per app: "
                            f"improve that one instead (ask its maker, or open an issue).")
    return not problems, problems, pid, is_new


def load_library(root):
    """The library as it stands, from a checkout of the repository's main branch."""
    import os
    def j(name, default):
        try:
            with open(os.path.join(root, name), encoding="utf-8") as f:
                return json.load(f)
        except (OSError, ValueError):
            return default
    withdrawn = set()
    try:
        with open(os.path.join(root, "withdrawn.txt"), encoding="utf-8") as f:
            withdrawn = {line.strip() for line in f if line.strip() and not line.startswith("#")}
    except OSError:
        pass
    apps = {}
    pdir = os.path.join(root, "plugins")
    for pid in sorted(os.listdir(pdir)) if os.path.isdir(pdir) else []:
        try:
            with open(os.path.join(pdir, pid, "manifest.json"), encoding="utf-8") as f:
                apps[pid] = loads_relaxed(f.read()).get("apps", [])
        except (OSError, ValueError, AttributeError):
            pass
    return {"authors": j("authors.json", {}), "levels": j("levels.json", {}), "withdrawn": withdrawn, "apps": apps}


def main():
    """For the GitHub check: library_rules.py <main checkout> <pull request checkout> <author> <changes file>.
    The changes file has one "status<TAB>path" per line (from GitHub's list of the pull request's files)."""
    import os
    base, pr, author, changes_file = sys.argv[1:5]
    with open(changes_file, encoding="utf-8") as f:
        changes = [tuple(reversed(line.rstrip("\n").split("\t", 1))) for line in f if "\t" in line]
    def read(path):
        full = os.path.realpath(os.path.join(pr, path))
        if not full.startswith(os.path.realpath(pr) + os.sep) or not os.path.isfile(full):
            return None
        with open(full, "rb") as fh:
            return fh.read()
    ok, problems, pid, is_new = check_submission(changes, read, author, load_library(base))
    if ok:
        print(f"Ready for TurnOver's full check: {pid} ({'new' if is_new else 'an update'}). "
              "TurnOver's Mac runs it within the hour and merges the plugin if it passes.")
        return 0
    print("Not ready yet:")
    for p in problems:
        print(f"- {p}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
