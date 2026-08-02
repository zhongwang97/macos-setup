#!/usr/bin/env bash
# GUI apps via Homebrew Cask (plus AI coding tools: CLI and desktop).
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
  jetbrains-toolbox
  raycast
  shottr
  appcleaner
  the-unarchiver
  iina
  localsend
  balenaetcher
  istat-menus
  "stats|Stats (menu bar system monitor)"
  "wetype|WeType (微信输入法)"
)

# AI coding tools kept in this module for convenience.
# Format: "kind:pkg_id|Human label"  where kind is cask|formula
# Some entries are terminal CLIs packaged as casks (no .app); labels say so.
AI_TOOLS=(
  "cask:cursor|Cursor — desktop IDE (.app)"
  "cask:codex|Codex CLI — terminal agent (bin/codex, not a .app)"
  "cask:chatgpt|ChatGPT desktop — GUI (.app); Codex desktop merged into this (codex-app is deprecated)"
  "cask:claude-code|Claude Code CLI — terminal agent (bin/claude, not a .app)"
  "cask:claude|Claude Desktop — GUI chat app (.app)"
  "cask:opencode-desktop|OpenCode Desktop — GUI app (.app)"
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

install_ai_tool() {
  local spec="$1"
  local kind_and_name="${spec%%|*}"
  local label="${spec#*|}"
  local kind="${kind_and_name%%:*}"
  local name="${kind_and_name#*:}"

  [[ "${label}" != "${spec}" ]] || label="${name}"

  if brew_installed "${name}"; then
    log_ok "already installed: ${name}"
    return 0
  fi
  if ! confirm "Install ${label}?"; then
    log_info "skipped ${name}"
    return 0
  fi
  case "${kind}" in
    cask)
      brew_cask_install "${name}" || log_warn "failed: ${name}"
      ;;
    formula)
      brew_install "${name}" || log_warn "failed: ${name}"
      ;;
    *)
      log_warn "unknown package kind '${kind}' for ${name}"
      ;;
  esac
}

for app in "${CASKS[@]}"; do
  install_cask "${app}"
done

cat <<EOF

${C_CYAN}${C_BOLD}AI coding tools (CLI vs desktop)${C_RESET}
${C_DIM}  CLI     = terminal binary (codex / claude-code); no Dock app
  Desktop = .app you open from Applications / Spotlight
  Note: OpenAI's standalone Codex.app was merged into ChatGPT desktop
        (brew cask: chatgpt). Prefer chatgpt over deprecated codex-app.
        OpenCode CLI formula (opencode) is not offered here — only the desktop cask.${C_RESET}

EOF

for tool in "${AI_TOOLS[@]}"; do
  install_ai_tool "${tool}"
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
