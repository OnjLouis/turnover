#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Tests for library_rules.py: python3 -I tools/test_library_rules.py"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from library_rules import check_submission, loads_relaxed  # noqa: E402

LIB = {"authors": {"xcode": "TurnOver-For-Mac", "slack": "alice"}, "levels": {"xcode": "Official", "slack": "Community"},
       "withdrawn": {"old-thing"}, "apps": {"xcode": ["com.apple.dt.Xcode"], "slack": ["com.tinyspeck.slackmacgap"]}}


def files(d):
    return lambda p: d.get(p)


def manifest(pid, apps, extra=""):
    return f'{{"id": "{pid}", "name": "N", "version": "1.0", "apps": {apps}{extra}}}'.encode()


class Rules(unittest.TestCase):
    def test_new_plugin_passes(self):
        d = {"plugins/zoom/manifest.json": manifest("zoom", '["us.zoom.xos"]'), "plugins/zoom/profile.json": b"{}"}
        ok, problems, pid, new = check_submission([(p, "added") for p in d], files(d), "bob", LIB)
        self.assertTrue(ok, problems); self.assertEqual(pid, "zoom"); self.assertTrue(new)

    def test_comments_and_trailing_commas(self):
        self.assertEqual(loads_relaxed('{ // a note\n "a": [1, 2,], /* x */ "b": "//not a comment", }'), {"a": [1, 2], "b": "//not a comment"})

    def test_outside_plugins_refused(self):
        d = {".github/workflows/guard.yml": b"x", "plugins/zoom/manifest.json": manifest("zoom", '["us.zoom.xos"]')}
        ok, problems, *_ = check_submission([(p, "added") for p in d], files(d), "bob", LIB)
        self.assertFalse(ok); self.assertIn(".github", problems[0])

    def test_library_files_refused(self):
        ok, problems, *_ = check_submission([("authors.json", "modified")], files({"authors.json": b"{}"}), "bob", LIB)
        self.assertFalse(ok)

    def test_two_plugins_refused(self):
        d = {"plugins/a/manifest.json": manifest("a", '["x.a"]'), "plugins/b/manifest.json": manifest("b", '["x.b"]')}
        ok, problems, *_ = check_submission([(p, "added") for p in d], files(d), "bob", LIB)
        self.assertFalse(ok); self.assertTrue(any("One plugin" in p for p in problems))

    def test_other_files_refused(self):
        d = {"plugins/zoom/manifest.json": manifest("zoom", '["us.zoom.xos"]'), "plugins/zoom/run.sh": b"rm -rf ~"}
        ok, problems, *_ = check_submission([(p, "added") for p in d], files(d), "bob", LIB)
        self.assertFalse(ok); self.assertTrue(any("run.sh" in p for p in problems))

    def test_path_tricks_refused(self):
        for path in ["plugins/../authors.json", "plugins/zoom/../../x", "plugins/.hidden/manifest.json", "plugins/zoom/tests/../../a.json"]:
            ok, *_ = check_submission([(path, "added")], files({path: b"{}"}), "bob", LIB)
            self.assertFalse(ok, path)

    def test_id_must_match_folder(self):
        d = {"plugins/zoom/manifest.json": manifest("slack", '["us.zoom.xos"]')}
        ok, problems, *_ = check_submission([(p, "added") for p in d], files(d), "bob", LIB)
        self.assertFalse(ok); self.assertTrue(any("must match" in p for p in problems))

    def test_only_the_owner_updates(self):
        d = {"plugins/slack/profile.json": b"{}", "plugins/slack/manifest.json": manifest("slack", '["com.tinyspeck.slackmacgap"]')}
        ok, problems, *_ = check_submission([("plugins/slack/profile.json", "modified")], files(d), "mallory", LIB)
        self.assertFalse(ok); self.assertIn("alice", problems[0])
        ok, problems, *_ = check_submission([("plugins/slack/profile.json", "modified")], files(d), "Alice", LIB)
        self.assertTrue(ok, problems)

    def test_official_plugins_closed_to_pull_requests(self):
        d = {"plugins/xcode/profile.json": b"{}", "plugins/xcode/manifest.json": manifest("xcode", '["com.apple.dt.Xcode"]')}
        ok, problems, *_ = check_submission([("plugins/xcode/profile.json", "modified")], files(d), "TurnOver-For-Mac", LIB)
        self.assertFalse(ok)

    def test_one_plugin_per_app(self):
        d = {"plugins/slack2/manifest.json": manifest("slack2", '["com.tinyspeck.slackmacgap"]')}
        ok, problems, *_ = check_submission([(p, "added") for p in d], files(d), "bob", LIB)
        self.assertFalse(ok); self.assertTrue(any("alice" in p for p in problems))

    def test_withdrawn_id_not_reused(self):
        d = {"plugins/old-thing/manifest.json": manifest("old-thing", '["x.y"]')}
        ok, problems, *_ = check_submission([(p, "added") for p in d], files(d), "bob", LIB)
        self.assertFalse(ok)

    def test_provides_refused(self):
        d = {"plugins/zoom/manifest.json": manifest("zoom", '["us.zoom.xos"]', ', "provides": "games"')}
        ok, problems, *_ = check_submission([(p, "added") for p in d], files(d), "bob", LIB)
        self.assertFalse(ok)

    def test_removing_the_manifest_refused(self):
        d = {"plugins/slack/manifest.json": manifest("slack", '["com.tinyspeck.slackmacgap"]')}
        ok, *_ = check_submission([("plugins/slack/manifest.json", "removed")], files(d), "alice", LIB)
        self.assertFalse(ok)

    def test_size_limit(self):
        d = {"plugins/zoom/manifest.json": manifest("zoom", '["us.zoom.xos"]'), "plugins/zoom/tests/screen-1.json": b'"' + b"a" * 1_000_001 + b'"'}
        ok, problems, *_ = check_submission([(p, "added") for p in d], files(d), "bob", LIB)
        self.assertFalse(ok); self.assertTrue(any("bytes" in p for p in problems))

    def test_tests_files_allowed(self):
        d = {"plugins/zoom/manifest.json": manifest("zoom", '["us.zoom.xos"]'), "plugins/zoom/tests/expect.json": b"[]"}
        ok, problems, *_ = check_submission([(p, "added") for p in d], files(d), "bob", LIB)
        self.assertTrue(ok, problems)


if __name__ == "__main__":
    unittest.main(verbosity=1)
