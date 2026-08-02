#!/usr/bin/env bash
# Install Homebrew and put the real brew prefix on PATH (.zprofile).

set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_macos
log_step "Homebrew"

# Official installer uses HEAD (not the old /master/ URL).
readonly BREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

# Discover an existing brew binary without trusting uname -m alone
# (Rosetta shells report x86_64 on Apple Silicon; custom prefixes also exist).
find_brew_bin() {
  if have_cmd brew; then
    command -v brew
    return 0
  fi
  local candidate
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "${candidate}" ]]; then
      printf '%s' "${candidate}"
      return 0
    fi
  done
  return 1
}

# Resolve the prefix for shellenv: prefer live `brew --prefix`.
resolve_brew_prefix() {
  local brew_bin="${1:-}"
  if [[ -n "${brew_bin}" && -x "${brew_bin}" ]]; then
    "${brew_bin}" --prefix
    return 0
  fi
  if have_cmd brew; then
    brew --prefix
    return 0
  fi
  # Fresh install fallback by machine hardware (not current process arch).
  local hw
  hw="$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)"
  if [[ "${hw}" == "1" ]]; then
    printf '%s' "/opt/homebrew"
  else
    printf '%s' "/usr/local"
  fi
}

activate_brew() {
  local brew_bin
  if ! brew_bin="$(find_brew_bin)"; then
    return 1
  fi
  # shellcheck disable=SC1090
  eval "$("${brew_bin}" shellenv)"
  have_cmd brew
}

write_brew_shellenv() {
  # Homebrew documents .zprofile for interactive login shells (not .zshenv).
  local brew_bin="$1"
  local prefix
  prefix="$(resolve_brew_prefix "${brew_bin}")"
  local brew_path="${prefix}/bin/brew"
  [[ -x "${brew_path}" ]] || die "brew not executable at ${brew_path} (prefix=${prefix})"

  local profile="${HOME}/.zprofile"
  local marker="# >>> macos-setup homebrew >>>"
  local end_marker="# <<< macos-setup homebrew <<<"
  local start_count

  touch "${profile}"
  validate_marked_block "${profile}" "${marker}" "${end_marker}"
  start_count="$(grep -Fc "${marker}" "${profile}" 2>/dev/null || true)"
  start_count="${start_count:-0}"

  if [[ "${start_count}" -eq 1 ]]; then
    if grep -Fq "${brew_path}" "${profile}" 2>/dev/null; then
      log_ok "brew shellenv already in ${profile} (${prefix})"
      return 0
    fi
    log_warn "updating stale brew shellenv block in ${profile}"
    remove_marked_block "${profile}" "${marker}" "${end_marker}"
  fi

  append_once "${profile}" "${marker}" <<EOF
eval "\$(${brew_path} shellenv)"
${end_marker}
EOF
}

if brew_bin="$(find_brew_bin)"; then
  activate_brew || die "found brew at ${brew_bin} but could not activate shellenv"
  log_ok "Homebrew already installed: $(command -v brew) (prefix=$(brew --prefix))"
  write_brew_shellenv "${brew_bin}"
  exit 0
fi

if ! confirm "Install Homebrew?"; then
  log_warn "skipped"
  exit 0
fi

log_info "running official Homebrew installer…"
install_script="$(curl -fsSL "${BREW_INSTALL_URL}")" \
  || die "failed to download Homebrew installer from ${BREW_INSTALL_URL}"
/bin/bash -c "${install_script}"

brew_bin="$(find_brew_bin)" || die "Homebrew installed but brew binary not found in PATH or standard prefixes"
activate_brew || die "could not activate brew shellenv"
write_brew_shellenv "${brew_bin}"

log_info "updating Homebrew…"
brew update

log_ok "Homebrew ready: $(brew --prefix)"
