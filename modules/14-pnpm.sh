#!/usr/bin/env bash
# pnpm via Homebrew; Node comes from fnm (no brew node formula).
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_macos
log_step "pnpm"

readonly EXPECTED_PNPM_MAJOR=11
readonly MIN_NODE_MAJOR=22
readonly MIN_NODE_MINOR=13

version_ge_min() {
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

if ! confirm "Install pnpm ${EXPECTED_PNPM_MAJOR}.x (requires fnm Node >=${MIN_NODE_MAJOR}.${MIN_NODE_MINOR})?"; then
  log_warn "skipped"
  exit 0
fi

ensure_brew

if have_cmd fnm; then
  eval "$(fnm env --shell bash)" || true
fi

if ! have_cmd node; then
  die "node not found. Run the fnm module first (./setup.sh --only fnm)."
fi

node_raw="$(node -v)"
if ! version_ge_min "${node_raw}"; then
  die "node ${node_raw} is below required >=${MIN_NODE_MAJOR}.${MIN_NODE_MINOR} for pnpm ${EXPECTED_PNPM_MAJOR}."
fi
log_ok "using node ${node_raw} from $(command -v node)"

brew_install pnpm

PNPM_BIN="$(brew_formula_bin pnpm)"
if [[ "$(command -v pnpm 2>/dev/null || true)" != "${PNPM_BIN}" ]]; then
  log_warn "PATH pnpm is $(command -v pnpm 2>/dev/null || echo none); setup uses ${PNPM_BIN}"
fi

pnpm_ver="$("${PNPM_BIN}" --version)"
pnpm_major="${pnpm_ver%%.*}"
if [[ "${pnpm_major}" != "${EXPECTED_PNPM_MAJOR}" ]]; then
  die "expected Homebrew pnpm major ${EXPECTED_PNPM_MAJOR} at ${PNPM_BIN}, got ${pnpm_ver}"
fi
log_ok "pnpm ${pnpm_ver} (${PNPM_BIN})"

log_ok "pnpm setup complete (no brew node; Node managed by fnm)"
