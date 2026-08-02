# macos-setup

Bootstrap a fresh macOS machine for development: Xcode CLT, Homebrew, Oh My Zsh,
CLI tools, GUI apps, fonts, and language toolchains (Java, Android, Flutter, Python,
Go, Node, pnpm).

## Quick start

```bash
chmod +x setup.sh modules/*.sh
./setup.sh
```

Non-interactive (auto-confirm prompts):

```bash
CONFIRM_ALL=1 ./setup.sh
```

Run a subset:

```bash
./setup.sh --only homebrew,cli,shell
./setup.sh --only corretto,android,fvm
./setup.sh --only fnm,pnpm
./setup.sh --list
```

## Layout

```
setup.sh                 # entry point
lib/common.sh            # logging, prompts, brew helpers (idempotent)
modules/
  01-xcode.sh
  02-homebrew.sh
  03-shell.sh
  04-cli-tools.sh
  05-apps.sh
  06-fonts.sh
  07-macos-defaults.sh
  08-corretto.sh         # Amazon Corretto 21
  09-android.sh          # Android command-line tools + SDK
  10-fvm.sh              # FVM + Flutter
  11-uv.sh               # uv + Python
  12-golang.sh           # Go
  13-fnm.sh              # fnm + Node LTS
  14-pnpm.sh             # pnpm (uses fnm Node)
config/
  Brewfile.cli           # declarative CLI formulae
```

## Dev toolchain versions (defaults)

| Tool | Default | Notes |
|------|---------|-------|
| Corretto | 21 | cask `corretto@21` |
| Android platform / build-tools | 36 / 36.0.0 | via `sdkmanager` |
| Flutter (FVM) | 3.38.9 | `FLUTTER_VERSION` override |
| Python (uv) | 3.13.14 | `PYTHON_VERSION` override |
| Go | 1.26.5 | brew `go`; warns if bottle differs |
| Node (fnm) | LTS | requires `>=22.13` for pnpm 11 |
| pnpm | 11.x | brew `pnpm`; **no** brew `node` |

## Shell config: zshenv vs zshrc vs zprofile

| File | Used for |
|------|----------|
| `~/.zprofile` | Homebrew `eval "$(brew shellenv)"` only (login) |
| `~/.zshenv` | Toolchain env + PATH (`JAVA_HOME`, `ANDROID_*`, `UV_DEFAULT_INDEX`, FVM Flutter PATH) |
| `~/.zshrc` | Interactive only: Oh My Zsh extras, `uv`/`uvx` completion, guarded `fnm env --use-on-cd` |

## What changed vs the old scripts

| Area | Old | Now |
|------|-----|-----|
| Homebrew installer | `…/install/master/install.sh` | official `…/install/HEAD/install.sh` |
| brew on PATH | append to `~/.zshenv` | `eval "$(brew shellenv)"` in `~/.zprofile` |
| Oh My Zsh | `robbyrussell/oh-my-zsh` | `ohmyzsh/ohmyzsh`, non-destructive install |
| Shell plugins | only syntax-highlighting; overwrite `.zshrc` | + autosuggestions; merge plugins; extras via markers |
| Directory jumper | `autojump` | `zoxide` |
| Fonts | `brew tap homebrew/cask-fonts` | casks in core (`font-*-nerd-font`) |
| Gatekeeper | `spctl --master-disable` | removed (unsupported); document per-app quarantine |
| Packages | ad-hoc `brew install` loops | `brew bundle --no-upgrade` + Brewfile |
| Scripts | no `set -e`, weak quoting | `set -euo pipefail`, idempotent helpers |
| Node | — | fnm LTS (not brew `node`); pnpm uses fnm’s Node |

## Notes

- Backups of touched files go to `~/.macos-setup-backups/`.
- GNU coreutils are optional and stay **g-prefixed** so they do not shadow BSD tools.
- PDF Expert / Magnet / Xcode / iWork remain App Store (or optional casks).
- Virtualization: prefer OrbStack / UTM / Docker Desktop on Apple Silicon over VirtualBox.
- After toolchain modules, open a new terminal (or `exec zsh`) so `.zshenv` / `.zshrc` changes apply.
