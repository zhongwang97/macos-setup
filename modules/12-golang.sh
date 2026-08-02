#!/usr/bin/env bash
# Go via Homebrew with pinned expected version and user-local caches.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_macos
log_step "Golang"

readonly EXPECTED_GO_VERSION="${GO_VERSION:-1.26.5}"
readonly GO_MOD_CACHE="${HOME}/Library/Caches/go-mod"
readonly GO_BUILD_CACHE="${HOME}/Library/Caches/go-build"
readonly GO_BIN_DIR="${HOME}/.local/bin"

if ! confirm "Install Go (expected ${EXPECTED_GO_VERSION})?"; then
  log_warn "skipped"
  exit 0
fi

ensure_brew
brew_install go

if ! have_cmd go; then
  die "go not on PATH after brew install"
fi

installed="$(go version 2>/dev/null || true)"
if [[ "${installed}" != *"${EXPECTED_GO_VERSION}"* ]]; then
  log_warn "expected Go ${EXPECTED_GO_VERSION}, got: ${installed}"
  log_warn "Homebrew may have rolled forward; continuing with installed version"
else
  log_ok "${installed}"
fi

mkdir -p "${GO_MOD_CACHE}" "${GO_BUILD_CACHE}" "${GO_BIN_DIR}"

go env -w "GOMODCACHE=${GO_MOD_CACHE}"
go env -w "GOCACHE=${GO_BUILD_CACHE}"
go env -w "GOBIN=${GO_BIN_DIR}"

ensure_path_front_in_zshenv "${GO_BIN_DIR}"
export PATH="${GO_BIN_DIR}:${PATH}"

log_ok "Go setup complete"
log_info "GOMODCACHE=$(go env GOMODCACHE)"
log_info "GOCACHE=$(go env GOCACHE)"
log_info "GOBIN=$(go env GOBIN)"
