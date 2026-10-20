import fcntl
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch
import rust_cleanup as rc


def cargo_target(path):
    profile = path / "debug"
    (profile / ".fingerprint").mkdir(parents=True)
    (profile / ".cargo-lock").touch()
    (profile / "deps").mkdir()
    (profile / "deps/test-binary").write_text("generated build output")
    (path / ".rustc_info.json").write_text("{}")
    return profile


class CleanupSafetyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        self.now = time.time() + 30 * rc.DAY
        self.cleaner = rc.Cleaner(self.home, now=self.now, apply=True)

    def tearDown(self):
        self.tmp.cleanup()

    def test_new_cache_gets_full_seven_day_buffer(self):
        target = self.home / ".cache/ocl-test/target"
        cargo_target(target)
        self.cleaner.process_cache(target)
        self.assertTrue(target.exists())
        self.assertEqual(self.cleaner.report["cleaned"], [])

    def test_observed_build_activity_restarts_the_full_idle_buffer(self):
        target = self.home / ".cache/ocl-test/target"
        cargo_target(target)
        self.cleaner.state[str(target)] = {"first_seen": self.now - 20 * rc.DAY,
                                          "idle_since": self.now - 20 * rc.DAY}
        self.cleaner.cache_targets = lambda: iter([target])
        self.cleaner.threads = lambda: {}
        with patch.object(rc, "busy_processes", return_value=["1:cargo"]):
            self.cleaner.run()
        self.assertIsNone(self.cleaner.state[str(target)]["idle_since"])
        self.cleaner.now += rc.DAY
        self.cleaner.cutoff = self.cleaner.now - 7 * rc.DAY
        with patch.object(rc, "busy_processes", return_value=[]):
            self.cleaner.run()
        self.assertEqual(self.cleaner.state[str(target)]["idle_since"], self.cleaner.now)
        self.assertTrue((target / "debug/deps/test-binary").exists())

    def test_cache_notes_and_source_are_kept(self):
        target = self.home / ".cache/ocl-test-target"
        cargo_target(target)
        note = target / "review-notes.md"
        note.write_text("keep these notes")
        source = self.home / "source.rs"
        source.write_text("keep this source")
        self.assertEqual(rc.clean_profiles(target, process_check=lambda: []), 1)
        self.assertFalse((target / "debug").exists())
        self.assertEqual(note.read_text(), "keep these notes")
        self.assertTrue(source.exists())

    def test_unrecognized_and_symlinked_targets_are_kept(self):
        target = self.home / "target"
        target.mkdir()
        (target / "source.rs").write_text("keep")
        self.assertEqual(rc.clean_profiles(target, process_check=lambda: []), 0)
        actual = self.home / "actual"
        cargo_target(actual)
        link = self.home / "linked-target"
        link.symlink_to(actual, target_is_directory=True)
        self.assertEqual(rc.clean_profiles(link, process_check=lambda: []), 0)
        self.assertTrue((actual / "debug/deps/test-binary").exists())

    def test_running_build_or_cargo_lock_prevents_deletion(self):
        target = self.home / "target"
        profile = cargo_target(target)
        with self.assertRaises(RuntimeError):
            rc.clean_profiles(target, process_check=lambda: ["1:cargo"])
        with (profile / ".cargo-lock").open() as held:
            fcntl.flock(held, fcntl.LOCK_EX | fcntl.LOCK_NB)
            with self.assertRaises(BlockingIOError):
                rc.clean_profiles(target, process_check=lambda: [])
        self.assertTrue((profile / "deps/test-binary").exists())

    def worktree(self):
        repo = self.cleaner.repo
        repo.mkdir(parents=True)
        subprocess.run(["git", "init", "-q", "-b", "main", str(repo)], check=True)
        rc.git(repo, "config", "user.name", "Cleanup test")
        rc.git(repo, "config", "user.email", "cleanup-test@example.invalid")
        (repo / ".gitignore").write_text("target/\nprivate-notes/\n")
        (repo / "source.rs").write_text("source code")
        rc.git(repo, "add", ".")
        rc.git(repo, "commit", "-qm", "Fixture source")
        path = self.cleaner.root / "test-worktree"
        path.parent.mkdir(parents=True)
        rc.git(repo, "worktree", "add", "-q", "-b", "feature/test", str(path))
        cargo_target(path / "target")
        thread = {"branch": "feature/test", "session_status": "stopped", "turn_state": "completed",
                  "pending_approval_count": 0, "pending_user_input_count": 0,
                  "has_actionable_proposed_plan": 0}
        for k in ("created_at", "latest_user_message_at", "requested_at", "started_at", "completed_at"):
            thread[k] = "2020-01-01T00:00:00Z"
        self.cleaner.state[str(path)] = {"first_seen": self.now - 8 * rc.DAY}
        self.cleaner.threads = lambda: {str(path): [thread]}
        return path, thread

    def test_unmerged_worktree_and_outputs_are_kept(self):
        path, thread = self.worktree()
        self.cleaner.merged_pr = lambda *args: None
        self.cleaner.process_worktree(path, [thread])
        self.assertTrue((path / "target/debug/deps/test-binary").exists())
        self.assertEqual(self.cleaner.report["cleaned"], [])

    def test_active_dirty_or_ignored_source_worktree_is_kept(self):
        path, thread = self.worktree()
        thread["session_status"] = "ready"
        self.assertIsNone(self.cleaner.validate_worktree(path, thread))
        thread["session_status"] = "stopped"
        (path / "source.rs").write_text("uncommitted source")
        self.assertIsNone(self.cleaner.validate_worktree(path, thread))
        rc.git(path, "restore", "source.rs")
        (path / "private-notes").mkdir()
        (path / "private-notes/notes.txt").write_text("ignored personal notes")
        self.assertIsNone(self.cleaner.validate_worktree(path, thread))

    def test_old_merged_worktree_removed_but_branch_and_source_retained(self):
        path, thread = self.worktree()
        self.cleaner.merged_pr = lambda *args: {"number": 1}
        with patch.object(rc, "busy_processes", return_value=[]):
            self.cleaner.process_worktree(path, [thread])
        self.assertFalse(path.exists())
        self.assertTrue((self.cleaner.repo / "source.rs").exists())
        self.assertIn("refs/heads/feature/test", rc.git(self.cleaner.repo, "show-ref"))
        self.assertIn(str(path), self.cleaner.report["cleaned"])

    def test_recent_use_and_recent_pr_merge_prevent_cleanup(self):
        path, thread = self.worktree()
        thread["completed_at"] = rc.dt.datetime.fromtimestamp(self.now - rc.DAY, rc.dt.timezone.utc).isoformat()
        self.assertIsNone(self.cleaner.validate_worktree(path, thread))
        recent = {"number": 1, "state": "MERGED", "headRefOid": "abc", "baseRefName": "main",
                  "mergedAt": rc.dt.datetime.fromtimestamp(self.now - rc.DAY, rc.dt.timezone.utc).isoformat()}
        with patch.object(rc, "command", side_effect=[rc.json.dumps([recent]), '{"defaultBranchRef":{"name":"main"}}']):
            self.assertIsNone(self.cleaner.merged_pr(path, "feature/test", "abc"))


if __name__ == "__main__":
    unittest.main()
