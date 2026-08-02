#!/usr/bin/env bash
# Amazon Corretto JDK 21 via Homebrew cask.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_macos
log_step "Amazon Corretto 21"

readonly JAVA_HOME_PATH="/Library/Java/JavaVirtualMachines/amazon-corretto-21.jdk/Contents/Home"

if ! confirm "Install Amazon Corretto JDK 21?"; then
  log_warn "skipped"
  exit 0
fi

ensure_brew
brew_cask_install "corretto@21"

if [[ ! -x "${JAVA_HOME_PATH}/bin/java" ]]; then
  die "Corretto 21 java not found at ${JAVA_HOME_PATH}/bin/java"
fi

export JAVA_HOME="${JAVA_HOME_PATH}"
export PATH="${JAVA_HOME}/bin:${PATH}"

write_marked_block "${HOME}/.zshenv" \
  "# >>> macos-setup corretto >>>" \
  "# <<< macos-setup corretto <<<" <<EOF
export JAVA_HOME="${JAVA_HOME_PATH}"
export PATH="\$JAVA_HOME/bin:\$PATH"
EOF

log_ok "Corretto 21: $("${JAVA_HOME}/bin/java" -version 2>&1 | head -n1)"
log_info "JAVA_HOME=${JAVA_HOME}"
