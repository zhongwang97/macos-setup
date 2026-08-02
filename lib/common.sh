#!/usr/bin/env bash
# Shared helpers for macos-setup. Source this file; do not execute it.

# Prevent double-sourcing
[[ -n "${_MACOS_SETUP_COMMON_LOADED:-}" ]] && return 0
_MACOS_SETUP_COMMON_LOADED=1

set -euo pipefail

# ---------------------------------------------------------------------------
# Colors (disabled when not a TTY or NO_COLOR is set)
# ---------------------------------------------------------------------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  readonly C_RESET=$'\033[0m'
  readonly C_BOLD=$'\033[1m'
  readonly C_DIM=$'\033[2m'
  readonly C_RED=$'\033[31m'
  readonly C_GREEN=$'\033[32m'
  readonly C_YELLOW=$'\033[33m'
  readonly C_BLUE=$'\033[34m'
  readonly C_CYAN=$'\033[36m'
else
  readonly C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_CYAN=''
fi

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log_info()  { printf '%s==>%s %s\n' "${C_BLUE}${C_BOLD}" "${C_RESET}" "$*"; }
log_ok()    { printf '%s[ok]%s %s\n' "${C_GREEN}${C_BOLD}" "${C_RESET}" "$*"; }
log_warn()  { printf '%s[warn]%s %s\n' "${C_YELLOW}${C_BOLD}" "${C_RESET}" "$*" >&2; }
log_error() { printf '%s[error]%s %s\n' "${C_RED}${C_BOLD}" "${C_RESET}" "$*" >&2; }
log_step()  {
  printf '\n%s------------------------------------------------------------%s\n' "${C_DIM}" "${C_RESET}"
  printf '%s%s%s\n' "${C_CYAN}${C_BOLD}" "$*" "${C_RESET}"
  printf '%s------------------------------------------------------------%s\n' "${C_DIM}" "${C_RESET}"
}

die() { log_error "$*"; exit 1; }

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
# Resolve repo root from this file's location (lib/ -> parent)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SCRIPT_DIR
readonly CONFIG_DIR="${SCRIPT_DIR}/config"
readonly MODULES_DIR="${SCRIPT_DIR}/modules"
readonly BACKUP_DIR="${HOME}/.macos-setup-backups"

timestamp() {
  # Wall-clock stamp for humans. Uniqueness for backups is handled in backup_file
  # (counters inside $(timestamp) are lost — command substitution runs in a subshell).
  date +"%Y-%m-%d_%H-%M-%S"
}

# ---------------------------------------------------------------------------
# Prompts
# ---------------------------------------------------------------------------
# confirm "message" -> returns 0 if yes. Default is NO unless CONFIRM_ALL=1.
confirm() {
  local prompt="${1:-Continue?}"
  if [[ "${CONFIRM_ALL:-0}" == "1" ]]; then
    log_info "${prompt} [auto-yes]"
    return 0
  fi
  local reply
  printf '%s [y/N] ' "${prompt}"
  read -r reply || true
  [[ "${reply}" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# Destructive actions (rm -rf, overwrite user data): NEVER auto-yes via CONFIRM_ALL.
# Default remains NO; requires an explicit y/yes on a TTY.
confirm_destructive() {
  local prompt="${1:-This is destructive. Continue?}"
  if [[ ! -t 0 ]]; then
    log_error "${prompt}"
    log_error "destructive confirmation requires an interactive TTY (CONFIRM_ALL cannot bypass)"
    return 1
  fi
  local reply
  printf '%s%s [y/N] %s' "${C_YELLOW}${C_BOLD}" "${prompt}" "${C_RESET}"
  read -r reply || true
  [[ "${reply}" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# Move a path aside into BACKUP_DIR (preserves full trees). Returns backup path on stdout.
# Prefer this over rm -rf for anything that may contain user data.
quarantine_path() {
  local src="$1"
  [[ -e "${src}" || -L "${src}" ]] || return 1
  mkdir -p "${BACKUP_DIR}"
  local base dest
  base="$(basename "${src}")"
  dest="${BACKUP_DIR}/${base}.$(timestamp).$$.${RANDOM}"
  while [[ -e "${dest}" ]]; do
    dest="${BACKUP_DIR}/${base}.$(timestamp).$$.${RANDOM}"
  done
  mv "${src}" "${dest}"
  log_ok "moved ${src} -> ${dest}"
  printf '%s' "${dest}"
}

# Ask for a string with optional default.
# Prompt MUST go to stderr: callers capture stdout via $(ask ...). Writing the
# prompt to stdout would bake "Prompt [default]: value" into the answer (and
# look like a hang, because nothing appears on the terminal).
ask() {
  local prompt="$1"
  local default="${2:-}"
  local reply
  if [[ -n "${default}" ]]; then
    printf '%s [%s]: ' "${prompt}" "${default}" >&2
  else
    printf '%s: ' "${prompt}" >&2
  fi
  read -r reply || true
  printf '%s' "${reply:-${default}}"
}

# ---------------------------------------------------------------------------
# File helpers
# ---------------------------------------------------------------------------
backup_file() {
  local file="$1"
  # Skip missing or empty files — nothing meaningful to restore.
  if [[ -e "${file}" || -L "${file}" ]] && [[ -s "${file}" ]]; then
    mkdir -p "${BACKUP_DIR}"
    local base dest
    base="$(basename "${file}")"
    # pid + RANDOM + retry loop: safe under rapid successive backups in the same second.
    # (Do not put a mutable counter inside $(...) — subshells discard increments.)
    dest="${BACKUP_DIR}/${base}.$(timestamp).$$.${RANDOM}"
    while [[ -e "${dest}" ]]; do
      dest="${BACKUP_DIR}/${base}.$(timestamp).$$.${RANDOM}"
    done
    cp -a "${file}" "${dest}"
    log_ok "backed up ${file} -> ${dest}"
  fi
}

# Append a block to a file only if a marker is absent (idempotent).
# Usage: append_once FILE MARKER <<'EOF'
# ...content...
# EOF
append_once() {
  local file="$1"
  local marker="$2"
  local content
  content="$(cat)"
  touch "${file}"
  if grep -Fqx "${marker}" "${file}" 2>/dev/null; then
    log_info "skip append (already present): ${marker}"
    return 0
  fi
  backup_file "${file}"
  {
    printf '\n%s\n' "${marker}"
    printf '%s\n' "${content}"
  } >> "${file}"
  log_ok "appended to ${file}"
}

# Validate start/end markers in FILE. Dies on incomplete, duplicate, or out-of-order.
# Safe no-op when neither marker is present.
validate_marked_block() {
  local file="$1"
  local start_marker="$2"
  local end_marker="$3"
  local start_count end_count start_line end_line

  start_count="$(grep -Fc "${start_marker}" "${file}" 2>/dev/null || true)"
  end_count="$(grep -Fc "${end_marker}" "${file}" 2>/dev/null || true)"
  start_count="${start_count:-0}"
  end_count="${end_count:-0}"

  if [[ "${start_count}" -eq 0 && "${end_count}" -eq 0 ]]; then
    return 0
  fi
  if [[ "${start_count}" -eq 1 && "${end_count}" -eq 1 ]]; then
    start_line="$(grep -Fn "${start_marker}" "${file}" | head -1 | cut -d: -f1)"
    end_line="$(grep -Fn "${end_marker}" "${file}" | head -1 | cut -d: -f1)"
    if [[ "${start_line}" -ge "${end_line}" ]]; then
      die "markers out of order in ${file} (start line ${start_line}, end line ${end_line}): ${start_marker}. Fix manually, then re-run."
    fi
    return 0
  fi
  die "incomplete or duplicate marker block in ${file} (start_count=${start_count} end_count=${end_count}): ${start_marker}. Fix or remove the markers manually, then re-run."
}

# Drop a validated start..end block from FILE (no-op if absent). Uses same-dir atomic replace.
remove_marked_block() {
  local file="$1"
  local start_marker="$2"
  local end_marker="$3"
  local tmp start_count

  [[ -f "${file}" ]] || return 0
  validate_marked_block "${file}" "${start_marker}" "${end_marker}"
  start_count="$(grep -Fc "${start_marker}" "${file}" 2>/dev/null || true)"
  start_count="${start_count:-0}"
  [[ "${start_count}" -eq 1 ]] || return 0

  backup_file "${file}"
  tmp="$(mktemp "${file}.XXXXXX")"
  awk -v s="${start_marker}" -v e="${end_marker}" '
    $0 == s { skip=1; next }
    $0 == e { skip=0; next }
    !skip { print }
  ' "${file}" >"${tmp}"
  if grep -Fq "${start_marker}" "${tmp}" 2>/dev/null || grep -Fq "${end_marker}" "${tmp}" 2>/dev/null; then
    rm -f "${tmp}"
    die "failed to strip marked block from ${file}; left file untouched"
  fi
  mv "${tmp}" "${file}"
  log_ok "removed marked block from ${file}: ${start_marker}"
}

# Write (or refresh) a marked block in FILE.
# Usage: write_marked_block FILE START_MARKER END_MARKER <<'EOF'
# ...content...
# EOF
write_marked_block() {
  local file="$1"
  local start_marker="$2"
  local end_marker="$3"
  local content tmp start_count sc ec
  content="$(cat)"
  touch "${file}"
  validate_marked_block "${file}" "${start_marker}" "${end_marker}"

  start_count="$(grep -Fc "${start_marker}" "${file}" 2>/dev/null || true)"
  start_count="${start_count:-0}"

  backup_file "${file}"
  # Same-directory tempfile so mv is atomic on the same filesystem.
  tmp="$(mktemp "${file}.XXXXXX")"

  if [[ "${start_count}" -eq 1 ]]; then
    {
      awk -v s="${start_marker}" -v e="${end_marker}" '
        $0 == s { skip=1; next }
        $0 == e { skip=0; next }
        !skip { print }
      ' "${file}"
      printf '\n%s\n' "${start_marker}"
      printf '%s\n' "${content}"
      printf '%s\n' "${end_marker}"
    } >"${tmp}"
    sc="$(grep -Fc "${start_marker}" "${tmp}" 2>/dev/null || true)"; sc="${sc:-0}"
    ec="$(grep -Fc "${end_marker}" "${tmp}" 2>/dev/null || true)"; ec="${ec:-0}"
    if [[ "${sc}" -ne 1 || "${ec}" -ne 1 ]]; then
      rm -f "${tmp}"
      die "failed to refresh marked block in ${file}; left file untouched"
    fi
    mv "${tmp}" "${file}"
    log_ok "refreshed marked block in ${file}: ${start_marker}"
    return 0
  fi

  {
    cat "${file}"
    printf '\n%s\n' "${start_marker}"
    printf '%s\n' "${content}"
    printf '%s\n' "${end_marker}"
  } >"${tmp}"
  mv "${tmp}" "${file}"
  log_ok "appended marked block to ${file}: ${start_marker}"
}

# Ensure PATH="$dir:$PATH" appears once in ~/.zshenv (idempotent).
ensure_path_front_in_zshenv() {
  local dir="$1"
  local zshenv="${HOME}/.zshenv"
  local line
  line="export PATH=\"${dir}:\$PATH\""
  touch "${zshenv}"

  # Upgrade a trailing append to a front prepend if present.
  local trail
  trail="export PATH=\"\$PATH:${dir}\""
  if grep -Fqx "${trail}" "${zshenv}" 2>/dev/null; then
    backup_file "${zshenv}"
    local tmp
    tmp="$(mktemp)"
    grep -Fxv "${trail}" "${zshenv}" >"${tmp}" || true
    cat "${tmp}" >"${zshenv}"
    rm -f "${tmp}"
  fi

  if grep -Fqx "${line}" "${zshenv}" 2>/dev/null; then
    log_info "skip PATH front (already present): ${dir}"
    return 0
  fi
  backup_file "${zshenv}"
  printf '\n%s\n' "${line}" >>"${zshenv}"
  log_ok "PATH front in ${zshenv}: ${dir}"
}

# ---------------------------------------------------------------------------
# Command / brew helpers
# ---------------------------------------------------------------------------
have_cmd() { command -v "$1" >/dev/null 2>&1; }

ensure_brew() {
  if have_cmd brew; then
    return 0
  fi
  # Common locations before PATH is refreshed
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    return 0
  fi
  if [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
    return 0
  fi
  die "Homebrew is not installed. Run the homebrew module first."
}

brew_installed() {
  ensure_brew
  brew list --formula "$1" &>/dev/null || brew list --cask "$1" &>/dev/null
}

brew_install() {
  local name="$1"
  shift || true
  ensure_brew
  if brew_installed "${name}"; then
    log_ok "already installed: ${name}"
    return 0
  fi
  log_info "brew install ${name} $*"
  brew install "$@" "${name}"
}

brew_cask_install() {
  local name="$1"
  ensure_brew
  if brew_installed "${name}"; then
    log_ok "already installed: ${name}"
    return 0
  fi
  log_info "brew install --cask ${name}"
  brew install --cask "${name}"
}

# Absolute path to a binary from a Homebrew formula (avoids PATH shadowing).
# Usage: brew_formula_bin FORMULA [COMMAND]
# FORMULA may be tap-qualified (leoafarias/fvm/fvm); COMMAND defaults to the short name.
brew_formula_bin() {
  local formula="$1"
  local short="${formula##*/}"
  local cmd="${2:-${short}}"
  local bin prefix
  ensure_brew
  bin="$(brew --prefix)/opt/${short}/bin/${cmd}"
  if [[ -x "${bin}" ]]; then
    printf '%s' "${bin}"
    return 0
  fi
  prefix="$(brew --prefix "${short}" 2>/dev/null || true)"
  if [[ -n "${prefix}" && -x "${prefix}/bin/${cmd}" ]]; then
    printf '%s' "${prefix}/bin/${cmd}"
    return 0
  fi
  die "Homebrew ${short} binary not found (expected $(brew --prefix)/opt/${short}/bin/${cmd})"
}

# Clone a git repo only if the destination does not exist.
git_clone_once() {
  local url="$1"
  local dest="$2"
  if [[ -d "${dest}/.git" ]]; then
    log_ok "already cloned: ${dest}"
    return 0
  fi
  if [[ -e "${dest}" ]]; then
    log_warn "destination exists but is not a git repo: ${dest}"
    return 1
  fi
  log_info "cloning ${url}"
  git clone --depth 1 "${url}" "${dest}"
}

require_macos() {
  [[ "$(uname -s)" == "Darwin" ]] || die "This script only supports macOS."
}

is_apple_silicon() {
  [[ "$(uname -m)" == "arm64" ]]
}
