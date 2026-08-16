# omarchy-supplement

Additional packages, dotfiles, and overrides to be used **after** installing [Omarchy](https://omarchy.org/). Run this **before** manually using the [dotfiles](https://github.com/janhesters/dotfiles) repo — `install-dotfiles.sh` clones and stows those dotfiles automatically.

## Scripts

| Script | Description |
|--------|-------------|
| `install-all.sh` | Run the Quattro-compatible setup scripts in order; legacy bar installers stay disabled until their plugin ports are ready |
| `install-ssh.sh` | Generate SSH key and configure GitHub access |
| `install-packages.sh` | Install system packages through `omarchy pkg`, and install Bun through mise (includes Espanso, Taskwarrior, and the teleprompter recording dependencies) |
| `install-keyd.sh` | Configure key remapping (CapsLock → Ctrl/Esc, Esc → Pause) |
| `install-ddcutil.sh` | Enable DDC/CI for external monitor brightness control |
| `install-scarlett.sh` | Fix distorted audio capture on Focusrite Scarlett 2i2 |
| `install-keyboard-layout.sh` | Set up Dvorak + US QWERTY switching with Left Alt + Right Alt, Pinyin with Ctrl+/, and the Omarchy Shell layout widget |
| `install-webapps.sh` | Install web apps (Claude, Claude Code, Google Mail, Google Calendar) |
| `install-dotfiles.sh` | Back up and Stow Quattro-compatible dotfiles, reload Hyprland, select Espanso's active layout profile, and start its layout-sync listener (includes shared global agent instructions) |
| `install-themes.sh` | Install extra Omarchy themes |
| `install-repos.sh` | Clone development repositories |
| `set-default-browser.sh` | Set Brave as the default browser |
| `set-default-terminal.sh` | Set Alacritty as the default terminal through Omarchy and `xdg-terminal-exec` |
| `set-default-pdf-viewer.sh` | Set Xournal++ as the default PDF viewer |
| `install-spellcheck.sh` | Install hunspell dictionaries for English and German spell checking |
| `install-claude.sh` | Install `typescript-language-server` and the Claude Code TypeScript plugin; settings, hooks, and shared instructions are owned by dotfiles |
| `install-grok.sh` | Install the Grok Build CLI via the official x.ai installer (user-level `~/.grok`, self-updating — the AUR package lags the beta releases); link `~/.grok/AGENTS.md` to `~/.agents/AGENTS.md` and set `permission_mode = "auto"` |
| `install-focus.sh` | Legacy Omarchy 3 focus indicator installer; excluded from `install-all.sh` until `omarchy-focus` becomes a Quattro shell plugin |
| `install-tasks.sh` | Legacy Omarchy 3 tasks indicator installer; excluded from `install-all.sh` until `omarchy-tasks` becomes a Quattro shell plugin |
| `install-teleprompter.sh` | Enable DisplayLink for the Elgato Prompter; the Super + Alt + P recording helper lives in dotfiles, and its Quattro shell indicator will be a separate plugin |
| `check-drift.sh` | Detect when omarchy template updates conflict with dotfile overrides |

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
