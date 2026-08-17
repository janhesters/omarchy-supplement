#!/bin/bash

# Sync Codex settings between the dotfiles base file and the live config.
#
# Codex owns ~/.codex/config.toml: it rewrites the file whenever you trust a
# folder, install a plugin, or switch models. That makes it unsuitable for a
# Stow symlink into the dotfiles repo -- the repo could never be clean, and any
# `git reset --hard` there silently wiped the live plugin and MCP state.
#
# So the live file is a real file that Codex owns, and the dotfiles repo tracks
# only the settings worth carrying to a new machine. Machine- and session-scoped
# state (plugins, marketplaces, MCP servers, per-session scratch trust entries)
# is deliberately left out.
#
# Usage:
#   install-codex-config.sh           Apply the tracked base to the live config,
#                                     preserving everything Codex has written.
#   install-codex-config.sh --pull    Snapshot the live config's durable settings
#                                     back into the tracked base.
#   install-codex-config.sh --check   Report durable drift; exit 1 if they differ.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dev/dotfiles}"
BASE_FILE="$DOTFILES_DIR/codex/.codex/config.base.toml"
LIVE_FILE="${CODEX_CONFIG:-${CODEX_HOME:-$HOME/.codex}/config.toml}"
MODE="${1:-push}"

case "$MODE" in
  push | --push) MODE=push ;;
  --pull) MODE=pull ;;
  --check) MODE=check ;;
  *)
    echo "[codex] Usage: install-codex-config.sh [--pull|--check]" >&2
    exit 1
    ;;
esac

# --pull is the direction that creates the base, so it may legitimately be absent.
if [[ ! -f $BASE_FILE && $MODE != pull ]]; then
  echo "[codex] Error: tracked base $BASE_FILE is missing. Update the dotfiles checkout first." >&2
  exit 1
fi

if [[ ! -d $(dirname "$BASE_FILE") ]]; then
  echo "[codex] Error: $(dirname "$BASE_FILE") does not exist. Is DOTFILES_DIR correct?" >&2
  exit 1
fi

if [[ -L $LIVE_FILE ]]; then
  echo "[codex] Error: $LIVE_FILE is still a symlink into the dotfiles repo."
  echo "[codex] Codex must own this file. Replace it with a real copy first:"
  echo "[codex]   cp --remove-destination \"\$(readlink -f '$LIVE_FILE')\" '$LIVE_FILE'"
  exit 1
fi

python3 - "$MODE" "$BASE_FILE" "$LIVE_FILE" <<'PY'
import os, sys, tomllib

mode, base_path, live_path = sys.argv[1], sys.argv[2], sys.argv[3]

# --- what counts as durable -------------------------------------------------
# Everything not named here is Codex's own runtime state and is never tracked.
DURABLE_SCALARS = (
    "model",
    "model_reasoning_effort",
    "sandbox_mode",
    "approval_policy",
    "approvals_reviewer",
    "service_tier",
    "notify",
)
DURABLE_TABLES = ("sandbox_workspace_write", "tui")
# model_availability_nux is a "you have N previews left" counter, not a setting.
VOLATILE_SUBTABLES = {"tui": ("model_availability_nux",)}
# Codex creates one trust entry per session under ~/Documents/Codex/<date>/<slug>.
# Those never recur, so tracking them would grow the file without ever helping.
SCRATCH_PROJECT_MARKER = os.path.join(os.path.expanduser("~"), "Documents", "Codex")

COMMENTS = {
    "tui": (
        "# Use the external Omarchy notifier instead of terminal OSC 9/BEL alerts,\n"
        "# which can request focus from the compositor.\n"
    ),
}

HEADER = """\
# Durable Codex settings, applied to ~/.codex/config.toml by
# omarchy-supplement/install-codex-config.sh.
#
# Codex owns the live file and rewrites it constantly, so only settings worth
# carrying to a new machine live here. Plugins, marketplaces, MCP servers and
# per-session scratch trust entries are deliberately excluded -- they are
# machine- or session-scoped and would churn on every commit.
#
# Edit a setting in Codex, then run `install-codex-config.sh --pull` to capture
# it here. Run the script with no arguments to apply this file to a machine.

"""


def durable(config):
    """Project the durable subset out of a parsed config."""
    out = {}

    for key in DURABLE_SCALARS:
        if key in config:
            out[key] = config[key]

    for table in DURABLE_TABLES:
        value = config.get(table)
        if not isinstance(value, dict):
            continue
        kept = {
            k: v
            for k, v in value.items()
            if k not in VOLATILE_SUBTABLES.get(table, ())
        }
        if kept:
            out[table] = kept

    projects = config.get("projects")
    if isinstance(projects, dict):
        kept = {
            path: settings
            for path, settings in projects.items()
            if not path.startswith(SCRATCH_PROJECT_MARKER)
        }
        if kept:
            out["projects"] = kept

    return out


# --- minimal TOML emitter ---------------------------------------------------
# Only the value types Codex actually writes; avoids a tomlkit/tomli-w dependency
# in a bootstrap script.
BARE = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")


def fmt_key(key):
    return key if key and set(key) <= BARE else fmt_str(key)


def fmt_str(value):
    escaped = (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\t", "\\t")
    )
    return f'"{escaped}"'


def fmt_value(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, str):
        return fmt_str(value)
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, list):
        return "[" + ", ".join(fmt_value(v) for v in value) + "]"
    raise TypeError(f"unsupported TOML value: {value!r}")


def dump(config, header=""):
    lines = [header] if header else []

    scalars = {k: v for k, v in config.items() if not isinstance(v, dict)}
    tables = {k: v for k, v in config.items() if isinstance(v, dict)}

    for key, value in scalars.items():
        lines.append(f"{fmt_key(key)} = {fmt_value(value)}\n")
    if scalars:
        lines.append("\n")

    def emit(path, table):
        comment = COMMENTS.get(".".join(path), "")
        own = {k: v for k, v in table.items() if not isinstance(v, dict)}
        sub = {k: v for k, v in table.items() if isinstance(v, dict)}

        # A table with only sub-tables needs no header of its own.
        if own or not sub:
            lines.append("[" + ".".join(fmt_key(p) for p in path) + "]\n")
            if comment:
                lines.append(comment)
            for key, value in own.items():
                lines.append(f"{fmt_key(key)} = {fmt_value(value)}\n")
            lines.append("\n")

        for key, value in sub.items():
            emit(path + [key], value)

    for key, value in tables.items():
        emit([key], value)

    return "".join(lines).rstrip("\n") + "\n"


def merge(live, base):
    """Base wins for durable keys; everything else Codex owns is preserved."""
    out = dict(live)
    for key, value in base.items():
        if isinstance(value, dict) and isinstance(out.get(key), dict):
            merged = dict(out[key])
            merged.update(value)
            out[key] = merged
        else:
            out[key] = value
    return out


def load(path):
    with open(path, "rb") as fh:
        return tomllib.load(fh)


base = load(base_path) if os.path.exists(base_path) else {}
live = load(live_path) if os.path.exists(live_path) else {}

if mode == "check":
    current, tracked = durable(live), durable(base)
    if current == tracked:
        print("[codex] Base is in sync with the live config's durable settings.")
        sys.exit(0)
    for key in sorted(set(current) | set(tracked)):
        if current.get(key) != tracked.get(key):
            print(f"  DRIFT: {key}")
    print("[codex] Run --pull to capture the live settings, or run with no args to apply the base.")
    sys.exit(1)

if mode == "pull":
    text = dump(durable(live), HEADER)
    with open(base_path, "w") as fh:
        fh.write(text)
    print(f"[codex] Snapshotted durable settings into {base_path}")
    sys.exit(0)

# push
merged = merge(live, durable(base))
if merged == live:
    print("[codex] Live config already matches the base, nothing to do.")
    sys.exit(0)

with open(live_path, "w") as fh:
    fh.write(dump(merged))
print(f"[codex] Applied base settings to {live_path}")
PY
