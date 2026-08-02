#!/usr/bin/env bash
# Install Xcode Command Line Tools (required by Homebrew and most builds).

set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_macos
log_step "Xcode Command Line Tools"

# Override with XCODE_CLT_TIMEOUT=seconds if needed (default 10 minutes).
readonly XCODE_CLT_TIMEOUT="${XCODE_CLT_TIMEOUT:-600}"

if xcode-select -p &>/dev/null; then
  log_ok "Command Line Tools already installed: $(xcode-select -p)"
  exit 0
fi

if ! confirm "Install Xcode Command Line Tools?"; then
  log_warn "skipped"
  exit 0
fi

log_info "triggering installer (GUI dialog)…"
# Non-zero is common when a dialog is already open; keep polling with a timeout.
xcode-select --install 2>/dev/null || true

log_info "waiting up to ${XCODE_CLT_TIMEOUT}s (Ctrl-C to abort; dismiss dialog = wait until timeout)…"
elapsed=0
interval=5
while ! xcode-select -p &>/dev/null; do
  if [[ "${elapsed}" -ge "${XCODE_CLT_TIMEOUT}" ]]; then
    die "timed out after ${XCODE_CLT_TIMEOUT}s waiting for Command Line Tools. Install via: xcode-select --install  then re-run this module."
  fi
  sleep "${interval}"
  elapsed=$((elapsed + interval))
  if (( elapsed % 30 == 0 )); then
    log_info "still waiting… (${elapsed}s / ${XCODE_CLT_TIMEOUT}s)"
  fi
done

log_ok "Command Line Tools installed: $(xcode-select -p)"
