#!/usr/bin/env bash
# Nerd Fonts — fonts live in homebrew/cask now (homebrew/cask-fonts tap is retired).

set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_macos
log_step "Fonts"

ensure_brew

FONTS=(
  font-fira-code-nerd-font
  font-jetbrains-mono-nerd-font
)

if ! confirm "Install Nerd Fonts (Fira Code + JetBrains Mono)?"; then
  log_warn "skipped"
  exit 0
fi

# Do NOT: brew tap homebrew/cask-fonts  (deprecated / merged into homebrew/cask)
for font in "${FONTS[@]}"; do
  brew_cask_install "${font}" || log_warn "failed: ${font}"
done

log_ok "fonts done — set the font in iTerm2 / VS Code / Cursor terminal settings"
