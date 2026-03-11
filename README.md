# omarchy-supplement

Additional packages, dotfiles, and overrides to be used **after** installing [Omarchy](https://omarchy.org/).

## Scripts

| Script | Description |
|--------|-------------|
| `install-all.sh` | Run all install scripts in order |
| `install-ssh.sh` | Generate SSH key and configure GitHub access |
| `install-packages.sh` | Install packages via `omarchy-pkg-add` and `omarchy-pkg-aur-add` |
| `install-keyd.sh` | Configure key remapping (CapsLock → Ctrl/Esc, Esc → Pause) |
| `install-ddcutil.sh` | Enable DDC/CI for external monitor brightness control |
| `install-keyboard-layout.sh` | Set up Dvorak + QWERTY + Pinyin keyboard layouts |
| `install-webapps.sh` | Install web apps (Claude, Google Mail, Google Calendar) |
| `install-dotfiles.sh` | Clone and stow dotfiles |
| `install-themes.sh` | Install extra Omarchy themes |
| `install-repos.sh` | Clone development repositories |
| `set-default-browser.sh` | Set Brave as the default browser |

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
