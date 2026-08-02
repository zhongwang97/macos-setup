#!/usr/bin/env bash
# uv (Astral) + pinned Python via Homebrew.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_macos
log_step "uv / Python"

readonly DEFAULT_PYTHON_VERSION="${PYTHON_VERSION:-3.13.14}"
readonly UV_INDEX="https://mirrors.aliyun.com/pypi/simple"

if ! confirm "Install uv and Python ${DEFAULT_PYTHON_VERSION}?"; then
  log_warn "skipped"
  exit 0
fi

ensure_brew
brew_install uv

UV_BIN="$(brew_formula_bin uv)"
if [[ "$(command -v uv 2>/dev/null || true)" != "${UV_BIN}" ]]; then
  log_warn "PATH uv is $(command -v uv 2>/dev/null || echo none); setup uses ${UV_BIN}"
fi

# uv tool installs land in ~/.local/bin; keep that for user tools, not for setup itself.
ensure_path_front_in_zshenv "${HOME}/.local/bin"
export UV_DEFAULT_INDEX="${UV_INDEX}"

write_marked_block "${HOME}/.zshenv" \
  "# >>> macos-setup uv >>>" \
  "# <<< macos-setup uv <<<" <<EOF
export UV_DEFAULT_INDEX="${UV_INDEX}"
EOF

write_marked_block "${HOME}/.zshrc" \
  "# >>> macos-setup uv completion >>>" \
  "# <<< macos-setup uv completion <<<" <<'EOF'
if command -v uv >/dev/null 2>&1; then
  eval "$(uv generate-shell-completion zsh)"
fi
if command -v uvx >/dev/null 2>&1; then
  eval "$(uvx --generate-shell-completion zsh)"
fi
EOF

py_ver="$(ask "Python version" "${DEFAULT_PYTHON_VERSION}")"

log_info "uv python install --default ${py_ver}"
"${UV_BIN}" python install --default "${py_ver}"
"${UV_BIN}" python pin --global "${py_ver}"

if confirm "Install ipython via uv tool?"; then
  "${UV_BIN}" tool install ipython --python "${py_ver}"
fi

log_ok "uv ready; Python ${py_ver} pinned globally"
"${UV_BIN}" --version
