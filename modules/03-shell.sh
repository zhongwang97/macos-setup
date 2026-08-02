#!/usr/bin/env bash
# Oh My Zsh + modern plugins (syntax-highlighting, autosuggestions).
# Does NOT overwrite an existing ~/.zshrc — merges via markers / plugin list.

set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_macos
log_step "Oh My Zsh & plugins"

readonly OMZ_DIR="${HOME}/.oh-my-zsh"
readonly OMZ_CUSTOM="${ZSH_CUSTOM:-${OMZ_DIR}/custom}"
readonly OMZ_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

# A usable install must include the main script (directory alone can be a failed half-install).
omz_is_healthy() {
  [[ -f "${OMZ_DIR}/oh-my-zsh.sh" && -d "${OMZ_DIR}/lib" ]]
}

install_oh_my_zsh() {
  if omz_is_healthy; then
    log_ok "Oh My Zsh already installed"
    return 0
  fi

  if [[ -e "${OMZ_DIR}" ]] && ! omz_is_healthy; then
    log_warn "incomplete Oh My Zsh at ${OMZ_DIR}"
    log_warn "directory may still contain custom/plugins, themes, or other user files"
    if ! confirm_destructive "Move broken ${OMZ_DIR} aside (full-tree backup) and reinstall?"; then
      die "refusing to continue with broken Oh My Zsh at ${OMZ_DIR} (CONFIRM_ALL cannot bypass this)"
    fi
    # Never rm -rf: quarantine the whole tree so custom/ is recoverable.
    quarantine_path "${OMZ_DIR}" >/dev/null
  fi

  if ! confirm "Install Oh My Zsh?"; then
    log_warn "skipped"
    return 2
  fi

  # Official org is ohmyzsh (not robbyrussell). KEEP_ZSHRC avoids clobbering.
  log_info "installing Oh My Zsh…"
  omz_script="$(curl -fsSL "${OMZ_INSTALL_URL}")" \
    || die "failed to download Oh My Zsh installer"

  # Do not rely on set -e inside functions under ||/&& lists — check explicitly.
  set +e
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "${omz_script}"
  local rc=$?
  set -e

  if [[ "${rc}" -ne 0 ]]; then
    die "Oh My Zsh installer failed (exit ${rc})"
  fi
  if ! omz_is_healthy; then
    die "Oh My Zsh installer finished but ${OMZ_DIR}/oh-my-zsh.sh is missing (half-install)"
  fi
  log_ok "Oh My Zsh installed"
  return 0
}

install_plugin() {
  local name="$1"
  local url="$2"
  local dest="${OMZ_CUSTOM}/plugins/${name}"
  git_clone_once "${url}" "${dest}"
}

ensure_plugin_in_zshrc() {
  local zshrc="${HOME}/.zshrc"
  local plugin="$1"
  [[ -f "${zshrc}" ]] || return 0

  # If plugins=(...) exists and does not list the plugin, insert it.
  if grep -Eq "^plugins=\(" "${zshrc}"; then
    if grep -Eq "^plugins=\([^)]*\b${plugin}\b" "${zshrc}"; then
      log_ok "plugin already listed: ${plugin}"
      return 0
    fi
    backup_file "${zshrc}"
    # Insert before the closing ) of the first plugins=(...) line/block (single-line form).
    if grep -Eq "^plugins=\([^)]*\)$" "${zshrc}"; then
      sed -i.bak -E "s/^(plugins=\([^)]*)\)/\1 ${plugin})/" "${zshrc}"
      rm -f "${zshrc}.bak"
      log_ok "added plugin to plugins=(): ${plugin}"
    else
      log_warn "plugins=() is multi-line; add '${plugin}' manually in ${zshrc}"
    fi
  fi
}

write_zsh_extras() {
  local zshrc="${HOME}/.zshrc"
  touch "${zshrc}"

  # Theme preference (only set if still default robbyrussell)
  if grep -Eq '^ZSH_THEME="robbyrussell"' "${zshrc}"; then
    backup_file "${zshrc}"
    sed -i.bak 's/^ZSH_THEME="robbyrussell"/ZSH_THEME="frisk"/' "${zshrc}"
    rm -f "${zshrc}.bak"
    log_ok "theme set to frisk"
  fi

  local marker="# >>> macos-setup zsh extras >>>"
  append_once "${zshrc}" "${marker}" <<'EOF'
# Tolerate unmatched globs (useful with some brew/git completions)
setopt no_nomatch

# Modern directory jumper (replaces autojump)
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# fzf keybindings / completion when available
if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh) 2>/dev/null || true
fi

# bat as a nicer cat/less
if command -v bat >/dev/null 2>&1; then
  alias cat="bat -pp"
  alias less="bat -p"
  export BAT_THEME="${BAT_THEME:-Monokai Extended Origin}"
fi

# eza as a nicer ls (when installed)
if command -v eza >/dev/null 2>&1; then
  alias ls="eza --group-directories-first"
  alias ll="eza -l --group-directories-first --git"
  alias la="eza -la --group-directories-first --git"
fi
# <<< macos-setup zsh extras <<<
EOF
}

# return 2 = user skipped → exit 0 from module; failures use die (exit 1)
# or a non-zero return. Keep set -e active inside the function; capture status
# via || so a skip (2) does not abort the script early.
omz_rc=0
install_oh_my_zsh || omz_rc=$?
case "${omz_rc}" in
  0) ;;
  2) exit 0 ;;
  *) die "Oh My Zsh setup failed (exit ${omz_rc})" ;;
esac

mkdir -p "${OMZ_CUSTOM}/plugins"

install_plugin "zsh-syntax-highlighting" \
  "https://github.com/zsh-users/zsh-syntax-highlighting.git"
install_plugin "zsh-autosuggestions" \
  "https://github.com/zsh-users/zsh-autosuggestions.git"

# Ensure a usable plugins=() line exists after a fresh OMZ install
if [[ -f "${HOME}/.zshrc" ]] && ! grep -Eq "^plugins=\(" "${HOME}/.zshrc"; then
  backup_file "${HOME}/.zshrc"
  printf '\nplugins=(git)\n' >> "${HOME}/.zshrc"
fi

# Core + modern plugins (autojump replaced by zoxide init in extras)
for p in git colored-man-pages fancy-ctrl-z fzf \
         zsh-autosuggestions zsh-syntax-highlighting; do
  ensure_plugin_in_zshrc "${p}"
done

write_zsh_extras
log_ok "shell configuration updated"
