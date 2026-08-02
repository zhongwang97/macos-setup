#!/usr/bin/env bash
# GUI apps via Brewfile.cask. Each cask can be confirmed, or use CONFIRM_ALL=1.

set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_macos
log_step "GUI applications"

ensure_brew

# Casks that are useful defaults for a modern Mac dev machine.
# pdf-expert is Mas/paid — keep optional; prefer brew cask when available.
CASKS=(
  google-chrome
  iterm2
  visual-studio-code
  jetbrains-toolbox
  raycast
  shottr
  appcleaner
  the-unarchiver
  iina
  balenaetcher
  istat-menus
)

if [[ "${CONFIRM_ALL:-0}" == "1" ]]; then
  if ! confirm "Install all listed GUI apps via Homebrew Cask?"; then
    log_warn "skipped"
    exit 0
  fi
  for app in "${CASKS[@]}"; do
    brew_cask_install "${app}" || log_warn "failed: ${app}"
  done
else
  for app in "${CASKS[@]}"; do
    if brew_installed "${app}"; then
      log_ok "already installed: ${app}"
      continue
    fi
    if confirm "Install ${app}?"; then
      brew_cask_install "${app}" || log_warn "failed: ${app}"
    else
      log_info "skipped ${app}"
    fi
  done
fi

# Optional paid / App Store notes
cat <<EOF

${C_DIM}App Store / manual (not covered by Homebrew):${C_RESET}
  • Xcode, Keynote / Numbers / Pages
  • Magnet, Manico
  • PDF Expert (also available as cask: brew install --cask pdf-expert)
  • Blackmagic Disk Speed Test

${C_DIM}Virtualization (pick one ecosystem):${C_RESET}
  • Apple Silicon: UTM or OrbStack / Docker Desktop
  • Intel legacy: VirtualBox (often needs manual install + extension pack)

EOF

log_ok "GUI apps done"
