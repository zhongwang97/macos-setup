#!/usr/bin/env bash
# FVM (Flutter Version Management) + pinned Flutter global via Homebrew tap.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_macos
log_step "FVM / Flutter"

readonly DEFAULT_FLUTTER_VERSION="${FLUTTER_VERSION:-3.38.9}"
readonly FVM_CACHE_PATH="${FVM_CACHE_PATH:-${HOME}/.fvm/cache}"

if ! confirm "Install FVM and Flutter ${DEFAULT_FLUTTER_VERSION}?"; then
  log_warn "skipped"
  exit 0
fi

ensure_brew

# Fully-qualified install authorizes only this formula under Homebrew 6 tap trust.
brew_install leoafarias/fvm/fvm

FVM_BIN="$(brew_formula_bin leoafarias/fvm/fvm fvm)"
if [[ "$(command -v fvm 2>/dev/null || true)" != "${FVM_BIN}" ]]; then
  log_warn "PATH fvm is $(command -v fvm 2>/dev/null || echo none); setup uses ${FVM_BIN}"
fi

flutter_ver="$(ask "Flutter version to install" "${DEFAULT_FLUTTER_VERSION}")"

# Use env(1): bash 3.2 rejects VAR=val cmd when VAR is readonly.
log_info "fvm install ${flutter_ver}"
env FVM_CACHE_PATH="${FVM_CACHE_PATH}" "${FVM_BIN}" install "${flutter_ver}"

log_info "fvm global ${flutter_ver}"
env FVM_CACHE_PATH="${FVM_CACHE_PATH}" "${FVM_BIN}" global "${flutter_ver}"

export FVM_CACHE_PATH
export PATH="${PATH}:${FVM_CACHE_PATH}/default/bin"

flutter_bin="${FVM_CACHE_PATH}/default/bin/flutter"
if [[ -x "${flutter_bin}" ]]; then
  if [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
    log_info "flutter config --android-sdk ${ANDROID_SDK_ROOT}"
    "${flutter_bin}" config --android-sdk "${ANDROID_SDK_ROOT}" || true
  elif [[ -d "$(brew --prefix 2>/dev/null)/share/android-commandlinetools" ]]; then
    sdk="$(brew --prefix)/share/android-commandlinetools"
    log_info "flutter config --android-sdk ${sdk}"
    "${flutter_bin}" config --android-sdk "${sdk}" || true
  fi
fi

write_marked_block "${HOME}/.zshenv" \
  "# >>> macos-setup fvm >>>" \
  "# <<< macos-setup fvm <<<" <<EOF
export FVM_CACHE_PATH="${FVM_CACHE_PATH}"
export PATH="\$PATH:\$FVM_CACHE_PATH/default/bin"
EOF

log_ok "FVM ready; Flutter ${flutter_ver} set as global"
log_info "Run: flutter doctor"
