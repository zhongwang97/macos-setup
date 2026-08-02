#!/usr/bin/env bash
# Git: global user.name / user.email for commits.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_macos
log_step "Git identity"

if ! confirm "Configure Git global user.name / user.email?"; then
  log_warn "skipped"
  exit 0
fi

if ! have_cmd git; then
  die "git not found. Run the cli module first (brew installs git)."
fi

# Prefer env overrides, then existing global config, then empty.
current_name="$(git config --global --get user.name 2>/dev/null || true)"
current_email="$(git config --global --get user.email 2>/dev/null || true)"
default_name="${GIT_USER_NAME:-${current_name}}"
default_email="${GIT_USER_EMAIL:-${current_email}}"

if [[ -n "${current_name}" || -n "${current_email}" ]]; then
  log_info "current: name='${current_name:-}'  email='${current_email:-}'"
fi

name="$(ask "Git user.name" "${default_name}")"
email="$(ask "Git user.email" "${default_email}")"

if [[ -z "${name}" && -z "${email}" ]]; then
  log_warn "empty name and email; nothing to set"
  log_warn "re-run interactively, or set GIT_USER_NAME / GIT_USER_EMAIL"
  exit 0
fi

if [[ -n "${name}" ]]; then
  git config --global user.name "${name}"
  log_ok "user.name = ${name}"
else
  log_warn "skipped user.name (empty)"
fi

if [[ -n "${email}" ]]; then
  if [[ ! "${email}" =~ .+@.+\..+ ]]; then
    log_warn "email looks unusual: ${email} (setting anyway)"
  fi
  git config --global user.email "${email}"
  log_ok "user.email = ${email}"
else
  log_warn "skipped user.email (empty)"
fi

log_ok "Git identity: $(git config --global --get user.name 2>/dev/null || echo '?') <$(git config --global --get user.email 2>/dev/null || echo '?')>"
