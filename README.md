# omarchy-supplement

Additional packages, dotfiles, and overrides to be used **after** installing [Omarchy](https://omarchy.org/). Run this **before** manually using the [dotfiles](https://github.com/janhesters/dotfiles) repo — `install-dotfiles.sh` clones and stows those dotfiles automatically.

## Scripts

| Script | Description |
|--------|-------------|
| `install-all.sh` | Run the Quattro-compatible setup scripts in order |
| `rust_cleanup.py` | Preview or run seven-day cleanup for OCL Rust builds and merged T3 worktrees |
| `install-ssh.sh` | Generate SSH key and configure GitHub access |
| `install-packages.sh` | Install system packages through `omarchy pkg`, and install Bun through mise (includes Blender, Espanso, Taskwarrior, and the teleprompter recording dependencies) |
| `install-keyd.sh` | Configure key remapping (CapsLock → Ctrl/Esc, Esc → Pause) |
| `install-ddcutil.sh` | Enable DDC/CI for external monitor brightness control |
| `install-scarlett.sh` | Fix distorted audio capture on Focusrite Scarlett 2i2 |
| `install-keyboard-layout.sh` | Set up Dvorak + US QWERTY switching with Left Alt + Right Alt, disable the retired Pinyin input method, and add the Omarchy Shell layout widget |
| `install-webapps.sh` | Install web apps (Claude, Claude Code, Google Mail, Google Calendar) |
| `install-dotfiles.sh` | Back up and Stow Quattro-compatible dotfiles, reload Hyprland, select Espanso's active layout profile, and start its layout-sync listener (includes shared global agent instructions) |
| `install-themes.sh` | Install extra Omarchy themes |
| `install-repos.sh` | Clone development repositories |
| `set-default-browser.sh` | Set Brave as the default browser |
| `set-default-terminal.sh` | Set Alacritty as the default terminal through Omarchy and `xdg-terminal-exec` |
| `set-default-pdf-viewer.sh` | Set Document Viewer (Evince) as the default PDF viewer |
| `install-spellcheck.sh` | Install hunspell dictionaries for English and German spell checking |
| `install-claude.sh` | Install `typescript-language-server` and the Claude Code TypeScript plugin; settings, hooks, and shared instructions are owned by dotfiles |
| `install-grok.sh` | Install the Grok Build CLI via the official x.ai installer (user-level `~/.grok`, self-updating — the AUR package lags the beta releases); link `~/.grok/AGENTS.md` to `~/.agents/AGENTS.md` and set `permission_mode = "auto"` |
| `install-focus.sh` | Block distracting websites (X, YouTube, Reddit) via `/etc/hosts`, with a Quattro shell indicator (`shell/indicators/Focus.qml`) that turns red while focus mode is on; click it to unblock |
| `install-tasks.sh` | Install and enable the `omarchy-tasks` Taskwarrior shell plugin |
| `install-nightlight.sh` | Install `shell/indicators/NightLight.qml`; switching night light back on restores the current scheduled color and brightness from `hyprsunset.conf`. Switching it off keeps brightness unchanged |
| `install-teleprompter.sh` | Enable DisplayLink for the Elgato Prompter; the Super + Alt + P recording helper lives in dotfiles. Installs `shell/indicators/ScreenRecording.qml`, which overrides the stock indicator so a teleprompter capture (cyan monitor glyph, orange while the watchdog waits for a dropped prompter) stays distinguishable from a gpu-screen-recorder one (red dot) |
| `install-codex-config.sh` | Apply the dotfiles' `config.base.toml` to `~/.codex/config.toml`, preserving everything Codex writes there itself. `--pull` snapshots durable settings back into the dotfiles; `--check` reports drift. Codex owns the live file, so it is deliberately not a Stow symlink |
| `check-drift.sh` | Detect when omarchy template updates conflict with dotfile overrides |
| `shell/install-shell-indicator.sh` | Install a custom indicator QML into a user-owned clone of the `omarchy.indicators` shell plugin, registering it in the plugin manifest and bar layout. Used by `install-focus.sh`, `install-nightlight.sh`, and `install-teleprompter.sh` |

## Usage

Run everything:

```bash
git clone git@github.com:janhesters/omarchy-supplement.git ~/dev/omarchy-supplement
cd ~/dev/omarchy-supplement
./install-all.sh
```

Or run individual scripts:

```bash
./install-packages.sh
./install-keyd.sh
```

## Rust build cleanup

`rust_cleanup.py` keeps Open Constructor Loop build outputs for at least seven days. The Codex cleanup heartbeat was removed at Jan's request. The cleaner currently runs only when invoked manually; a replacement scheduler has not been enabled. The first run starts a seven-day observation period, so enabling cleanup does not delete existing outputs.

Preview the policy:

```bash
python3 ~/dev/omarchy-supplement/rust_cleanup.py
```

Run cleanup and update its observation state:

```bash
python3 ~/dev/omarchy-supplement/rust_cleanup.py --apply
```

Run these commands on the host. The cleaner refuses to use a process-isolated sandbox because it cannot see active builds there. It skips cleanup while Rust builds or OCL test binaries run. It also takes Cargo's build-directory locks before cleaning.

The scope covers recognized `debug` and `release` outputs under `~/.cache/ocl-*/target`, `~/.cache/ocl-*-target`, and `/tmp/ocl-*-target`. Recent file use resets the seven-day buffer. Observed build activity also restarts the buffer; cleanup waits for seven days of observed build inactivity. Notes and other files alongside build outputs stay. Unknown build layouts and symlinked paths stay.

Worktree cleanup covers only T3's `~/.t3/worktrees/open-constructor-loop` folders registered to `~/dev/open-constructor-loop`. A worktree qualifies after its PR has been merged into the repository's default branch for seven days, its thread has been idle for seven days, and it has been observed for seven days. The cleaner verifies the PR on GitHub and requires the checkout to match its last PR commit. Open sessions, pending work, shared worktrees, uncommitted changes, and ignored files other than Cargo's target folder and `node_modules` prevent removal.

Git removes eligible worktrees without force. Branches, source in the main checkout, and T3's chat history stay. T3's immediate merge-cleanup policy stays off so it cannot bypass the buffer. State and the run lock live in `~/.local/state/rust-cleanup/`.

Run the safety tests:

```bash
cd ~/dev/omarchy-supplement
python3 -m unittest discover -s tests -p test_rust_cleanup.py -v
```
