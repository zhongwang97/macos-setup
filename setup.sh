#!/usr/bin/env bash
# macos-setup — interactive bootstrap for a fresh Mac developer machine.
#
# Usage:
#   ./setup.sh                  # guided run (all modules, confirm each step)
#   CONFIRM_ALL=1 ./setup.sh    # accept defaults / yes to confirms
#   ./setup.sh --only homebrew,cli,shell
#   ./setup.sh --list
#
# Compatible with macOS system Bash 3.2+ (no associative arrays).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${ROOT}/lib/common.sh"

require_macos

MODULE_ORDER="xcode homebrew shell cli apps fonts defaults corretto android fvm uv golang fnm pnpm ssh git"

module_file() {
  case "$1" in
    xcode)    printf '%s' "${MODULES_DIR}/01-xcode.sh" ;;
    homebrew) printf '%s' "${MODULES_DIR}/02-homebrew.sh" ;;
    shell)    printf '%s' "${MODULES_DIR}/03-shell.sh" ;;
    cli)      printf '%s' "${MODULES_DIR}/04-cli-tools.sh" ;;
    apps)     printf '%s' "${MODULES_DIR}/05-apps.sh" ;;
    fonts)    printf '%s' "${MODULES_DIR}/06-fonts.sh" ;;
    defaults) printf '%s' "${MODULES_DIR}/07-macos-defaults.sh" ;;
    corretto) printf '%s' "${MODULES_DIR}/08-corretto.sh" ;;
    android)  printf '%s' "${MODULES_DIR}/09-android.sh" ;;
    fvm)      printf '%s' "${MODULES_DIR}/10-fvm.sh" ;;
    uv)       printf '%s' "${MODULES_DIR}/11-uv.sh" ;;
    golang)   printf '%s' "${MODULES_DIR}/12-golang.sh" ;;
    fnm)      printf '%s' "${MODULES_DIR}/13-fnm.sh" ;;
    pnpm)     printf '%s' "${MODULES_DIR}/14-pnpm.sh" ;;
    ssh)      printf '%s' "${MODULES_DIR}/15-ssh.sh" ;;
    git)      printf '%s' "${MODULES_DIR}/16-git.sh" ;;
    *)        return 1 ;;
  esac
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

  (no args)              Run all modules interactively
  --only m1,m2,…         Run only the named modules (comma-separated)
  --list                 List available modules
  --help                 Show this help

Environment:
  CONFIRM_ALL=1          Answer yes to confirmation prompts
  NO_COLOR=1             Disable ANSI colors

Modules: ${MODULE_ORDER}
EOF
}

list_modules() {
  local name file
  for name in ${MODULE_ORDER}; do
    file="$(module_file "${name}")"
    printf '  %-12s %s\n' "${name}" "${file}"
  done
}

run_module() {
  local name="$1"
  local file
  if ! file="$(module_file "${name}")"; then
    die "unknown module: ${name}"
  fi
  [[ -f "${file}" ]] || die "module file missing: ${file}"
  bash "${file}"
}

# ---- args ----
# ONLY_MODE=1 means --only was requested (even if the value is empty/invalid).
ONLY_MODE=0
ONLY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --list)
      list_modules
      exit 0
      ;;
    --only)
      ONLY_MODE=1
      shift
      ONLY="${1:-}"
      [[ -n "${ONLY}" ]] || die "--only requires a comma-separated list"
      ;;
    --only=*)
      ONLY_MODE=1
      ONLY="${1#--only=}"
      [[ -n "${ONLY}" ]] || die "--only= requires a comma-separated list (got empty value)"
      ;;
    *)
      die "unknown argument: $1 (see --help)"
      ;;
  esac
  shift
done

log_step "macos-setup"
log_info "repo: ${ROOT}"
log_info "arch: $(uname -m)  |  macOS: $(sw_vers -productVersion 2>/dev/null || echo '?')"

failed=0
ran_any=0

run_named_modules() {
  # Split on commas without unquoted expansion (avoids pathname globbing).
  local csv="$1"
  local rest part name
  rest="${csv},"
  while [[ -n "${rest}" ]]; do
    part="${rest%%,*}"
    rest="${rest#*,}"
    name="$(printf '%s' "${part}" | tr -d '[:space:]')"
    [[ -n "${name}" ]] || continue
    ran_any=1
    if ! run_module "${name}"; then
      log_error "module failed: ${name}"
      failed=1
    fi
  done
}

if [[ "${ONLY_MODE}" -eq 1 ]]; then
  run_named_modules "${ONLY}"
  [[ "${ran_any}" -eq 1 ]] || die "--only matched no modules (got: '${ONLY}')"
else
  for name in ${MODULE_ORDER}; do
    if ! run_module "${name}"; then
      log_error "module failed: ${name}"
      failed=1
    fi
  done
fi

if [[ "${failed}" -ne 0 ]]; then
  die "one or more modules failed"
fi

log_step "done"
log_ok "Open a new terminal (or: exec zsh) so PATH / Oh My Zsh changes take effect."
