#!/usr/bin/env python3
"""Keep OCL build outputs for seven days; remove only completed, idle worktrees."""
import argparse
import collections
import contextlib
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import sqlite3
import subprocess
import tempfile
import time

DAY = 86400
REPOSITORY = "janhesters/open-constructor-loop"
BUILD_PROCESSES = {"cargo", "rustc", "clippy-driver", "ld.lld", "rust-lld"}


def timestamp(value):
    return dt.datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp() if value else 0


def command(args, cwd=None):
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=45,
                            env={**os.environ, "GIT_OPTIONAL_LOCKS": "0", "GH_PROMPT_DISABLED": "1"})
    if result.returncode:
        raise RuntimeError(f"{args[0]} failed: {result.stderr.strip()[:300]}")
    if len(result.stdout) > 1048576:
        raise RuntimeError("Command output exceeds the cleanup safety limit")
    return result.stdout


def git(path, *args):
    return command(["git", "--no-optional-locks", "-C", str(path), *args])


def busy_processes():
    """Require the host namespace; an isolated sandbox cannot prove builds are idle."""
    if Path("/proc/1/comm").read_text().strip() != "systemd":
        raise RuntimeError("Run on the host, outside a PID-isolated sandbox")
    found = []
    home = Path.home()
    executable_roots = [home / ".t3/worktrees/open-constructor-loop", home / ".cache"]
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            name = (entry / "comm").read_text().strip()
            if name in BUILD_PROCESSES:
                found.append(f"{entry.name}:{name}")
                continue
            try:
                executable = (entry / "exe").resolve(strict=True)
            except (FileNotFoundError, PermissionError):
                continue
            if any(executable.is_relative_to(root) for root in executable_roots[:1]) or (
                executable.is_relative_to(executable_roots[1])
                and executable.relative_to(executable_roots[1]).parts[0].startswith("ocl-")
            ) or (executable.is_relative_to(Path("/tmp"))
                  and executable.relative_to(Path("/tmp")).parts[0].startswith("ocl-")):
                found.append(f"{entry.name}:{name}")
        except FileNotFoundError:
            pass
        except PermissionError as exc:
            raise RuntimeError("Cannot inspect host processes; skipping cleanup") from exc
    return found


def plain_directory(path):
    return path.is_dir() and not path.is_symlink() and path.resolve() == path.absolute()


def build_profiles(target):
    if not plain_directory(target):
        return []
    return [p for p in (target / "debug", target / "release")
            if plain_directory(p) and (p / ".cargo-lock").is_file()
            and not (p / ".cargo-lock").is_symlink()
            and plain_directory(p / ".fingerprint")]


def newest_use(target):
    newest = 0
    for root, dirs, files in os.walk(target, followlinks=False):
        dirs[:] = [name for name in dirs if not (Path(root) / name).is_symlink()]
        for path in [Path(root), *(Path(root) / name for name in files)]:
            st = path.lstat()
            newest = max(newest, st.st_mtime, st.st_ctime, st.st_atime if path.is_file() else 0)
    return newest


@contextlib.contextmanager
def profile_locks(profiles):
    locks = []
    try:
        for profile in profiles:
            fd = os.open(profile / ".cargo-lock", os.O_RDONLY | os.O_NOFOLLOW)
            locks.append(fd)
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield
    finally:
        for fd in locks:
            os.close(fd)


def clean_profiles(target, process_check=None):
    """Leave notes and arbitrary files in mixed target roots untouched."""
    profiles = build_profiles(target)
    if not profiles:
        return 0
    with profile_locks(profiles):
        if (process_check or busy_processes)():
            raise RuntimeError("A build started; cleanup deferred")
        for profile in profiles:
            if not plain_directory(target) or not plain_directory(profile):
                raise RuntimeError("Build path changed during cleanup")
            quarantine = target / (".rust-cleanup-" + profile.name + "-" + str(os.getpid()))
            if quarantine.exists() or quarantine.is_symlink():
                raise RuntimeError("A prior cleanup needs inspection")
            profile.rename(quarantine)
            shutil.rmtree(quarantine)
    # Only remove Cargo's generated metadata and empty folders.
    for name in (".rustc_info.json", "CACHEDIR.TAG"):
        path = target / name
        if path.is_file() and not path.is_symlink():
            path.unlink()
    for name in ("tmp",):
        path = target / name
        if plain_directory(path):
            try:
                path.rmdir()
            except OSError:
                pass
    try:
        target.rmdir()
    except OSError:
        pass
    return len(profiles)


class Cleaner:
    def __init__(self, home, now=None, apply=False):
        self.home = Path(home)
        self.now = time.time() if now is None else now
        self.cutoff = self.now - 7 * DAY
        self.apply = apply
        self.repo = self.home / "dev/open-constructor-loop"
        self.root = self.home / ".t3/worktrees/open-constructor-loop"
        self.db = self.home / ".t3/userdata/state.sqlite"
        self.state_dir = self.home / ".local/state/rust-cleanup"
        self.state_file = self.state_dir / "state.json"
        self.state = json.loads(self.state_file.read_text()) if self.state_file.exists() else {}
        self.report = {"mode": "apply" if apply else "preview", "retention_days": 7,
                       "cleaned": [], "eligible": [], "skipped": collections.Counter(), "errors": []}

    def seen(self, path):
        key = str(path)
        if key not in self.state:
            self.state[key] = {"first_seen": self.now}
        return self.state[key]["first_seen"]

    def buffer_started(self, path):
        seen = self.seen(path)
        idle = self.state[str(path)].get("idle_since", seen)
        return self.now if idle is None else max(seen, idle)

    def threads(self):
        with sqlite3.connect(f"file:{self.db}?mode=ro", uri=True) as conn:
            conn.row_factory = sqlite3.Row
            rows = conn.execute("""
                SELECT t.*, p.workspace_root, s.status AS session_status,
                       r.state AS turn_state, r.requested_at, r.started_at, r.completed_at
                FROM projection_threads t JOIN projection_projects p USING(project_id)
                LEFT JOIN projection_thread_sessions s USING(thread_id)
                LEFT JOIN projection_turns r ON r.thread_id=t.thread_id AND r.turn_id=t.latest_turn_id
                WHERE t.worktree_path IS NOT NULL AND p.workspace_root=?
            """, (str(self.repo),)).fetchall()
        groups = collections.defaultdict(list)
        for row in rows:
            groups[row["worktree_path"]].append(dict(row))
        return groups

    def idle_thread(self, thread):
        if thread["session_status"] not in (None, "stopped") or thread["turn_state"] not in (None, "completed", "error", "interrupted"):
            return False
        if any(thread[k] for k in ("pending_approval_count", "pending_user_input_count", "has_actionable_proposed_plan")):
            return False
        activity = max(timestamp(thread[k]) for k in (
            "created_at", "latest_user_message_at", "requested_at", "started_at", "completed_at"))
        return activity < self.cutoff

    def merged_pr(self, path, branch, head):
        prs = json.loads(command(["gh", "pr", "list", "--repo", REPOSITORY, "--head", branch,
                                  "--state", "all", "--limit", "100", "--json",
                                  "number,state,mergedAt,headRefOid,baseRefName"]))
        if len(prs) >= 100 or any(p["state"] == "OPEN" for p in prs):
            return None
        default = json.loads(command(["gh", "repo", "view", REPOSITORY, "--json", "defaultBranchRef"]))["defaultBranchRef"]["name"]
        matches = [p for p in prs if p["state"] == "MERGED" and p["headRefOid"] == head
                   and p["baseRefName"] == default and timestamp(p["mergedAt"]) < self.cutoff]
        return max(matches, key=lambda p: p["mergedAt"], default=None)

    def validate_worktree(self, path, thread):
        if not plain_directory(self.root) or path.parent != self.root or not plain_directory(path):
            return None
        dotgit = path / ".git"
        if not dotgit.is_file() or dotgit.is_symlink():
            return None
        if not self.idle_thread(thread) or self.buffer_started(path) >= self.cutoff:
            return None
        if git(path, "symbolic-ref", "--quiet", "--short", "HEAD").strip() != thread["branch"]:
            return None
        if git(path, "status", "--porcelain", "--untracked-files=all"):
            return None
        ignored = git(path, "ls-files", "--others", "--ignored", "--exclude-standard", "--directory", "-z")
        if any(p and p != "target/" and not re.search(r"(^|/)node_modules/$", p) for p in ignored.split("\0")):
            return None
        registered = git(self.repo, "worktree", "list", "--porcelain", "-z")
        blocks = registered.split("\0\0")
        block = next((b for b in blocks if b.startswith("worktree " + str(path) + "\0")), "")
        if not block or "\0locked" in block:
            return None
        return git(path, "rev-parse", "HEAD").strip()

    def cache_targets(self):
        for base in (self.home / ".cache", Path("/tmp")):
            if not plain_directory(base):
                continue
            for entry in base.glob("ocl-*"):
                if not plain_directory(entry):
                    continue
                candidates = [entry / "target"] if base != Path("/tmp") else []
                if entry.name.endswith("-target"):
                    candidates.append(entry)
                for target in candidates:
                    if build_profiles(target):
                        yield target

    def process_cache(self, target):
        if self.buffer_started(target) >= self.cutoff:
            self.report["skipped"]["seven_day_observation_buffer"] += 1
            return
        if newest_use(target) >= self.cutoff:
            self.report["skipped"]["recent_build_output"] += 1
            return
        self.report["eligible"].append(str(target))
        if self.apply and clean_profiles(target):
            self.report["cleaned"].append(str(target))
            self.state[str(target)]["first_seen"] = self.now

    def process_worktree(self, path, group):
        self.seen(path)
        if len(group) != 1:
            self.report["skipped"]["shared_worktree"] += 1
            return
        thread = group[0]
        head = self.validate_worktree(path, thread)
        if not head:
            self.report["skipped"]["worktree_not_idle_or_safe_for_seven_days"] += 1
            return
        pr = self.merged_pr(path, thread["branch"], head)
        if not pr:
            self.report["skipped"]["pr_not_merged_to_default_branch_for_seven_days"] += 1
            return
        target = path / "target"
        if target.exists():
            if not build_profiles(target) or newest_use(target) >= self.cutoff:
                self.report["skipped"]["unrecognized_or_recent_target"] += 1
                return
        self.report["eligible"].append(str(path))
        if not self.apply:
            return
        # Re-read live app state and source before any mutation.
        fresh = self.threads().get(str(path), [])
        if len(fresh) != 1 or self.validate_worktree(path, fresh[0]) != head or busy_processes():
            self.report["skipped"]["work_resumed"] += 1
            return
        if target.exists():
            clean_profiles(target)
            self.report["cleaned"].append(str(target))
        if target.exists():
            self.report["skipped"]["target_contains_other_files_kept"] += 1
            return
        fresh = self.threads().get(str(path), [])
        if len(fresh) != 1 or self.validate_worktree(path, fresh[0]) != head or busy_processes():
            self.report["skipped"]["work_resumed"] += 1
            return
        git(self.repo, "worktree", "remove", str(path))  # Never force; never delete the branch.
        self.report["cleaned"].append(str(path))

    def run(self):
        busy = busy_processes()
        caches = list(self.cache_targets())
        threads = self.threads()
        for path in [*caches, *(Path(p) for p in threads)]:
            self.seen(path)
            record = self.state[str(path)]
            if busy:
                record["idle_since"] = None
            elif record.get("idle_since") is None:
                record["idle_since"] = self.now
        if busy:
            self.report["skipped"]["active_builds"] = len(busy)
            self.report["active_builds"] = busy[:12]
        else:
            for path in caches:
                try:
                    self.process_cache(path)
                except Exception as exc:
                    self.report["errors"].append({"path": str(path), "error": str(exc)})
            for raw, group in threads.items():
                try:
                    self.process_worktree(Path(raw), group)
                except Exception as exc:
                    self.report["errors"].append({"path": raw, "error": str(exc)})
        if self.apply:
            self.state_dir.mkdir(parents=True, exist_ok=True)
            fd, name = tempfile.mkstemp(prefix="state-", dir=self.state_dir)
            try:
                with os.fdopen(fd, "w") as f:
                    json.dump(self.state, f, indent=2)
                    f.write("\n")
                os.replace(name, self.state_file)
            finally:
                if os.path.exists(name):
                    os.unlink(name)
        return self.report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Clean eligible outputs; default is preview")
    args = parser.parse_args()
    cleaner = Cleaner(Path.home(), apply=args.apply)
    cleaner.state_dir.mkdir(parents=True, exist_ok=True)
    with (cleaner.state_dir / "run.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print(json.dumps({"skipped": "another_cleanup_is_running"}))
            return 0
        report = cleaner.run()
    print(json.dumps(report, indent=2))
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
