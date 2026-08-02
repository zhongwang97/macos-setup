#!/usr/bin/env bash
# Android SDK command-line tools via Homebrew + sdkmanager components.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_macos
log_step "Android SDK"

readonly DEFAULT_PLATFORM="${ANDROID_PLATFORM:-36}"
readonly DEFAULT_BUILD_TOOLS="${ANDROID_BUILD_TOOLS:-${DEFAULT_PLATFORM}.0.0}"

if ! confirm "Install Android command-line tools and SDK components?"; then
  log_warn "skipped"
  exit 0
fi

if ! have_cmd java; then
  die "java not found. Run the corretto module first (./setup.sh --only corretto)."
fi

ensure_brew
brew_cask_install android-commandlinetools

ANDROID_SDK_ROOT="$(brew --prefix)/share/android-commandlinetools"
readonly ANDROID_SDK_ROOT
SDKMANAGER="${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager"
[[ -x "${SDKMANAGER}" ]] || die "sdkmanager not found at ${SDKMANAGER}"

export ANDROID_SDK_ROOT
export ANDROID_HOME="${ANDROID_SDK_ROOT}"
export PATH="${PATH}:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools"

platform_ver="$(ask "Android platform version" "${DEFAULT_PLATFORM}")"
build_tools_default="${ANDROID_BUILD_TOOLS:-${platform_ver}.0.0}"
build_tools_ver="$(ask "Build tools version" "${build_tools_default}")"

log_info "Accepting SDK licenses..."
yes | "${SDKMANAGER}" --sdk_root="${ANDROID_SDK_ROOT}" --licenses >/dev/null || true

log_info "Installing platform-tools, platforms;android-${platform_ver}, build-tools;${build_tools_ver}"
"${SDKMANAGER}" --sdk_root="${ANDROID_SDK_ROOT}" \
  "platform-tools" \
  "platforms;android-${platform_ver}" \
  "build-tools;${build_tools_ver}"

write_marked_block "${HOME}/.zshenv" \
  "# >>> macos-setup android >>>" \
  "# <<< macos-setup android <<<" <<EOF
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT}"
export ANDROID_HOME="\$ANDROID_SDK_ROOT"
export PATH="\$PATH:\$ANDROID_SDK_ROOT/cmdline-tools/latest/bin"
export PATH="\$PATH:\$ANDROID_SDK_ROOT/platform-tools"
EOF

log_ok "Android SDK root: ${ANDROID_SDK_ROOT}"
log_info "platform=${platform_ver} build-tools=${build_tools_ver}"
