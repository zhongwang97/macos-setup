#!/usr/bin/env bash
# SSH: ~/.ssh dir, ed25519 key with passphrase, generic config + macOS Keychain.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_macos
log_step "SSH keys & Keychain"

readonly SSH_DIR="${HOME}/.ssh"
readonly KEY_PATH="${SSH_DIR}/id_ed25519"
readonly PUB_PATH="${KEY_PATH}.pub"
readonly CONFIG_PATH="${SSH_DIR}/config"
readonly CONFIG_START="# >>> macos-setup ssh >>>"
readonly CONFIG_END="# <<< macos-setup ssh <<<"
readonly ZSHRC_MARKER="# >>> macos-setup ssh agent >>>"

if ! confirm "Configure SSH (ed25519 key + Keychain)?"; then
  log_warn "skipped"
  exit 0
fi

mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

generate_key() {
  local comment default_comment
  default_comment="$(whoami)@$(hostname -s 2>/dev/null || hostname)"
  comment="$(ask "SSH key comment" "${default_comment}")"

  log_info "generating ${KEY_PATH} (ssh-keygen will prompt for passphrase twice)"
  # Interactive passphrase only — never pass -N / env secrets.
  ssh-keygen -t ed25519 -f "${KEY_PATH}" -C "${comment}"
  chmod 600 "${KEY_PATH}"
  chmod 644 "${PUB_PATH}"
  log_ok "key pair created"
}

ensure_key() {
  if [[ -f "${KEY_PATH}" ]]; then
    log_ok "key already exists: ${KEY_PATH}"
    if [[ -f "${PUB_PATH}" ]]; then
      log_info "public key: ${PUB_PATH}"
    else
      log_warn "private key present but public key missing: ${PUB_PATH}"
    fi
    # Do not auto-overwrite. To regenerate: quarantine/remove the key, then re-run.
    return 0
  fi

  if [[ "${CONFIRM_ALL:-0}" == "1" ]]; then
    log_warn "CONFIRM_ALL=1: skipping key generation (passphrase requires a TTY)"
    log_warn "re-run interactively: ./setup.sh --only ssh"
    return 0
  fi

  if [[ ! -t 0 ]]; then
    log_warn "no TTY: skipping key generation"
    return 0
  fi

  generate_key
}

write_ssh_config() {
  touch "${CONFIG_PATH}"
  write_marked_block "${CONFIG_PATH}" "${CONFIG_START}" "${CONFIG_END}" <<'EOF'
Host *
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF
  chmod 600 "${CONFIG_PATH}"
}

load_keychain() {
  if [[ ! -f "${KEY_PATH}" ]]; then
    log_warn "no private key at ${KEY_PATH}; skip ssh-add"
    return 0
  fi

  log_info "adding key to agent + Keychain (may prompt for passphrase once)"
  set +e
  ssh-add --apple-use-keychain "${KEY_PATH}"
  local rc=$?
  set -e
  if [[ "${rc}" -eq 0 ]]; then
    log_ok "key loaded into agent / Keychain"
  else
    log_warn "ssh-add failed (exit ${rc}); add later with: ssh-add --apple-use-keychain ${KEY_PATH}"
  fi
}

write_zshrc_agent() {
  local zshrc="${HOME}/.zshrc"
  touch "${zshrc}"
  append_once "${zshrc}" "${ZSHRC_MARKER}" <<'EOF'
# Load SSH keys from macOS Keychain into the agent (quiet if already loaded / no keys).
if command -v ssh-add >/dev/null 2>&1; then
  ssh-add --apple-load-keychain >/dev/null 2>&1 || true
fi
# <<< macos-setup ssh agent <<<
EOF
}

ensure_key
write_ssh_config
load_keychain
write_zshrc_agent

if [[ -f "${PUB_PATH}" ]]; then
  log_ok "public key (${PUB_PATH}):"
  cat "${PUB_PATH}"
  log_info "copy the line above to remote authorized_keys / hosting provider"
fi

log_ok "SSH setup complete — after Keychain stores the passphrase, new SSH sessions should not re-prompt"
