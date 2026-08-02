#!/usr/bin/env bash
# Optional macOS system tweaks (hostname). Gatekeeper "master-disable" is gone.

set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_macos
log_step "macOS defaults"

# Bonjour / DNS LocalHostName: ASCII letters, digits, hyphens; 1–63 chars;
# must not start/end with hyphen. (RFC 1123 hostname label subset.)
is_valid_local_hostname() {
  local n="$1"
  [[ "${#n}" -ge 1 && "${#n}" -le 63 ]] || return 1
  [[ "${n}" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$ ]] || return 1
  return 0
}

# Derive a DNS-safe LocalHostName from a friendly ComputerName.
to_local_hostname() {
  local raw="$1"
  local out
  # Replace spaces/underscores with hyphen; strip invalid chars; collapse hyphens.
  out="$(printf '%s' "${raw}" \
    | tr '[:upper:]' '[:lower:]' \
    | tr ' _' '--' \
    | sed -E 's/[^a-z0-9-]+//g; s/-+/-/g; s/^-//; s/-$//' \
    | cut -c1-63)"
  # Edge: empty or ends up hyphen-only after strip.
  if [[ -z "${out}" ]]; then
    out="$(whoami | tr -cd 'A-Za-z0-9-' | tr '[:upper:]' '[:lower:]')"
    out="${out:-mac}-host"
  fi
  # Ensure doesn't start/end with hyphen after cut.
  out="$(printf '%s' "${out}" | sed -E 's/^-//; s/-$//')"
  printf '%s' "${out}"
}

# ---- Hostname ----
if confirm "Set computer hostname?"; then
  current_computer="$(scutil --get ComputerName 2>/dev/null || true)"
  current_local="$(scutil --get LocalHostName 2>/dev/null || true)"

  default_computer="${current_computer:-}"
  if [[ -z "${default_computer}" ]]; then
    default_computer="$(whoami)-Mac"
  fi
  computer_name="$(ask "ComputerName (display name)" "${default_computer}")"
  if [[ -z "${computer_name}" ]]; then
    log_warn "empty ComputerName — skipped"
  else
    suggested_local="$(to_local_hostname "${computer_name}")"
    if [[ -n "${current_local}" ]] && is_valid_local_hostname "${current_local}"; then
      # Prefer existing LocalHostName as default when still valid.
      suggested_local="${current_local}"
    fi

    local_name="$(ask "LocalHostName / HostName (DNS-safe)" "${suggested_local}")"
    if ! is_valid_local_hostname "${local_name}"; then
      die "invalid LocalHostName '${local_name}' — use only A–Z, a–z, 0–9, hyphen; 1–63 chars; no leading/trailing hyphen"
    fi

    # Apply in an order that leaves a consistent trio, failing fast.
    # ComputerName may contain spaces/Unicode; LocalHostName/HostName must not.
    log_info "setting ComputerName='${computer_name}' LocalHostName='${local_name}' HostName='${local_name}'"
    sudo scutil --set ComputerName "${computer_name}"
    sudo scutil --set LocalHostName "${local_name}"
    sudo scutil --set HostName "${local_name}"

    # Verify all three stuck; otherwise surface inconsistency instead of silent partial apply.
    got_c="$(scutil --get ComputerName)"
    got_l="$(scutil --get LocalHostName)"
    got_h="$(scutil --get HostName)"
    if [[ "${got_c}" != "${computer_name}" || "${got_l}" != "${local_name}" || "${got_h}" != "${local_name}" ]]; then
      die "hostname verification failed (ComputerName='${got_c}' LocalHostName='${got_l}' HostName='${got_h}')"
    fi
    log_ok "hostname set (ComputerName='${got_c}', LocalHostName='${got_l}')"
  fi
fi

# ---- Gatekeeper note ----
# `spctl --master-disable` was removed / no-ops on modern macOS (Ventura+).
# Prefer per-app quarantine clear or System Settings > Privacy & Security.
log_info "Gatekeeper: do not use spctl --master-disable (unsupported on modern macOS)."
log_info "To open an unsigned app once: right-click → Open, or:"
log_info "  xattr -dr com.apple.quarantine /Applications/SomeApp.app"

log_ok "macOS defaults done"
