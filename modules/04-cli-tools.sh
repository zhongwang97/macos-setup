#!/usr/bin/env bash
# CLI tools via Brewfile (formulae).
# Uses --no-upgrade so already-installed formulae are left alone (install-only).


set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_macos
log_step "CLI tools"

ensure_brew

readonly BREWFILE="${CONFIG_DIR}/Brewfile.cli"

if [[ ! -f "${BREWFILE}" ]]; then
  die "missing ${BREWFILE}"
fi

if ! confirm "Install CLI tools from Brewfile.cli?"; then
  log_warn "skipped"
  exit 0
fi

log_info "brew bundle --no-upgrade --file=${BREWFILE}"
brew bundle --no-upgrade --file="${BREWFILE}"

# Optional GNU coreutils (prefixed with g* by default — avoids shadowing BSD tools)
if confirm "Install GNU coreutils / findutils / gnu-sed (g-prefixed)?"; then
  brew_install coreutils
  brew_install findutils
  brew_install gnu-sed
  brew_install moreutils
  log_info "GNU tools use g-prefix (e.g. gsed, gfind). Add to PATH if desired:"
  log_info "  export PATH=\"\$(brew --prefix)/opt/coreutils/libexec/gnubin:\$PATH\""
fi

log_ok "CLI tools done"
