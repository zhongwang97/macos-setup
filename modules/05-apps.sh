#!/usr/bin/env bash
# GUI apps via Homebrew Cask (plus a few AI coding agents that ship as casks).
# Whole module is optional; each item can also be confirmed individually
# (CONFIRM_ALL=1 auto-yeses both levels).

set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_macos
log_step "GUI applications"

if ! confirm "Install GUI apps (and related AI coding tools)?"; then
  log_warn "skipped"
  exit 0
fi

ensure_brew

# Homebrew Casks. Labels are shown in prompts; empty label falls back to cask id.
# Format: "cask_id" or "cask_id|Human label"
CASKS=(
  google-chrome
  iterm2
  visual-studio-code
  cursor
  jetbrains-toolbox
  raycast
  shottr
  appcleaner
  the-unarchiver
  iina
  localsend
  balenaetcher
  istat-menus
  "wetype|WeType (微信输入法)"
  "codex|Codex (OpenAI coding agent)"
  "claude-code|Claude Code"
  "opencode-desktop|OpenCode"
)

install_cask() {
  local spec="$1"
  local name="${spec%%|*}"
  local label="${spec#*|}"
  [[ "${label}" != "${spec}" ]] || label="${name}"

  if brew_installed "${name}"; then
    log_ok "already installed: ${name}"
    return 0
  fi
  if confirm "Install ${label}?"; then
    brew_cask_install "${name}" || log_warn "failed: ${name}"
  else
    log_info "skipped ${name}"
  fi
}

for app in "${CASKS[@]}"; do
  install_cask "${app}"
done

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

${C_DIM}WeType note:${C_RESET}
  • After install, enable 微信输入法 in System Settings → Keyboard → Input Sources
  • If it does not appear, open WeType.app once, then re-check Input Sources

EOF

log_ok "GUI apps done"
