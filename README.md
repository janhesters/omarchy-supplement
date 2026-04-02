# omarchy-supplement

Additional packages, dotfiles, and overrides to be used **after** installing [Omarchy](https://omarchy.org/). Run this **before** manually using the [dotfiles](https://github.com/janhesters/dotfiles) repo — `install-dotfiles.sh` clones and stows those dotfiles automatically.

## Scripts

| Script | Description |
|--------|-------------|
| `install-all.sh` | Run all install scripts in order |
| `install-ssh.sh` | Generate SSH key and configure GitHub access |
| `install-packages.sh` | Install packages via `omarchy-pkg-add` and `omarchy-pkg-aur-add` (includes espanso-wayland for text expansion) |
| `install-keyd.sh` | Configure key remapping (CapsLock → Ctrl/Esc, Esc → Pause) |
| `install-ddcutil.sh` | Enable DDC/CI for external monitor brightness control |
| `install-scarlett.sh` | Fix distorted audio capture on Focusrite Scarlett 2i2 |
| `install-keyboard-layout.sh` | Set up Dvorak + QWERTY + Pinyin keyboard layouts |
| `install-webapps.sh` | Install web apps (Claude, Claude Code, Google Mail, Google Calendar) |
| `install-dotfiles.sh` | Clone and stow dotfiles |
| `install-themes.sh` | Install extra Omarchy themes |
| `install-repos.sh` | Clone development repositories |
| `set-default-browser.sh` | Set Brave as the default browser |
| `set-default-pdf-viewer.sh` | Set Xournal++ as the default PDF viewer |
| `install-spellcheck.sh` | Install hunspell dictionaries for English and German spell checking |
| `install-claude.sh` | Configure Claude Code settings, notification hook, and system instructions |
| `install-focus.sh` | Block distracting websites (X, YouTube, Reddit) with a waybar indicator |
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
