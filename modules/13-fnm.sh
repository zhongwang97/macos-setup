#!/usr/bin/env bash
# fnm + Node LTS. Init only in .zshrc (fnm env has multishell side effects).
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_macos
log_step "fnm / Node"

readonly DEFAULT_NODE_VERSION="${NODE_VERSION:-lts}"
# pnpm 11 engines.node
readonly MIN_NODE_MAJOR=22
readonly MIN_NODE_MINOR=13

version_ge_min() {
  # Compare node -v (vX.Y.Z) against MIN_NODE_MAJOR.MIN_NODE_MINOR
  local raw="$1"
  local major minor
  raw="${raw#v}"
  major="${raw%%.*}"
  minor="${raw#*.}"
  minor="${minor%%.*}"
  if [[ "${major}" -gt "${MIN_NODE_MAJOR}" ]]; then
    return 0
  fi
  if [[ "${major}" -eq "${MIN_NODE_MAJOR}" && "${minor}" -ge "${MIN_NODE_MINOR}" ]]; then
    return 0
  fi
  return 1
}

if ! confirm "Install fnm and Node (${DEFAULT_NODE_VERSION})?"; then
  log_warn "skipped"
  exit 0
fi

ensure_brew
brew_install fnm

FNM_BIN="$(brew_formula_bin fnm)"
if [[ "$(command -v fnm 2>/dev/null || true)" != "${FNM_BIN}" ]]; then
  log_warn "PATH fnm is $(command -v fnm 2>/dev/null || echo none); setup uses ${FNM_BIN}"
fi

# Session: load env so install/use works under bash.
eval "$("${FNM_BIN}" env --shell bash)"

node_ver="$(ask "Node version (lts or exact)" "${DEFAULT_NODE_VERSION}")"

if [[ "${node_ver}" == "lts" || "${node_ver}" == "--lts" ]]; then
  log_info "fnm install --lts --use"
  "${FNM_BIN}" install --lts --use
  "${FNM_BIN}" default lts-latest
else
  log_info "fnm install ${node_ver} --use"
  "${FNM_BIN}" install "${node_ver}" --use
  "${FNM_BIN}" default "${node_ver}"
fi

# Refresh PATH after install.
eval "$("${FNM_BIN}" env --shell bash)"

if ! have_cmd node; then
  die "node not on PATH after fnm install"
fi

node_raw="$(node -v)"
if ! version_ge_min "${node_raw}"; then
  die "node ${node_raw} is below required >=${MIN_NODE_MAJOR}.${MIN_NODE_MINOR} (pnpm 11). Install a newer LTS."
fi

# Drop legacy .zshenv init (ran for every zsh, including non-interactive).
remove_marked_block "${HOME}/.zshenv" \
  "# >>> macos-setup fnm >>>" \
  "# <<< macos-setup fnm <<<"

# Migrate previous .zshrc marker name if present.
remove_marked_block "${HOME}/.zshrc" \
  "# >>> macos-setup fnm use-on-cd >>>" \
  "# <<< macos-setup fnm use-on-cd <<<"

write_marked_block "${HOME}/.zshrc" \
  "# >>> macos-setup fnm >>>" \
  "# <<< macos-setup fnm <<<" <<'EOF'
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi
EOF

log_ok "fnm ready; default node ${node_raw}"
node -v
npm -v 2>/dev/null || true
