#!/usr/bin/env bash
# Requires a full Java 21 JDK (including javac), curl, tar, xz, unzip and git. Review platform licenses first.
set -euo pipefail
command -v javac >/dev/null || { echo "Install a full JDK 21: javac is missing" >&2; exit 1; }
: "${HIZ_TOOLCHAIN_DIR:?Set HIZ_TOOLCHAIN_DIR to a writable directory outside the repo}"
mkdir -p "$HIZ_TOOLCHAIN_DIR"
if [[ ! -x "$HIZ_TOOLCHAIN_DIR/flutter/bin/flutter" ]]; then
  curl -fL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.9-stable.tar.xz -o "$HIZ_TOOLCHAIN_DIR/flutter.tar.xz"
  (cd "$HIZ_TOOLCHAIN_DIR" && echo '25ed8c3c29d51a7353f2a944310b478af8214920639524b19c50a19e6c044c5a  flutter.tar.xz' | sha256sum -c -)
  tar -xf "$HIZ_TOOLCHAIN_DIR/flutter.tar.xz" -C "$HIZ_TOOLCHAIN_DIR"
  rm "$HIZ_TOOLCHAIN_DIR/flutter.tar.xz"
fi
if [[ ! -x "$HIZ_TOOLCHAIN_DIR/android-sdk/cmdline-tools/latest/bin/sdkmanager" ]]; then
  curl -fL https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip -o "$HIZ_TOOLCHAIN_DIR/android-tools.zip"
  mkdir -p "$HIZ_TOOLCHAIN_DIR/android-sdk/cmdline-tools"
  unzip -q "$HIZ_TOOLCHAIN_DIR/android-tools.zip" -d "$HIZ_TOOLCHAIN_DIR/android-sdk/cmdline-tools"
  mv "$HIZ_TOOLCHAIN_DIR/android-sdk/cmdline-tools/cmdline-tools" "$HIZ_TOOLCHAIN_DIR/android-sdk/cmdline-tools/latest"
  rm "$HIZ_TOOLCHAIN_DIR/android-tools.zip"
fi
export ANDROID_USER_HOME="$HIZ_TOOLCHAIN_DIR/android-user"
mkdir -p "$ANDROID_USER_HOME/cache"
proxy_args=()
if [[ -n "${HTTPS_PROXY:-}" ]]; then
  proxy_address="${HTTPS_PROXY#*://}"
  proxy_args=(--proxy=http "--proxy_host=${proxy_address%:*}" "--proxy_port=${proxy_address##*:}")
fi
sdkmanager="$HIZ_TOOLCHAIN_DIR/android-sdk/cmdline-tools/latest/bin/sdkmanager"
"$sdkmanager" "${proxy_args[@]}" --licenses
"$sdkmanager" "${proxy_args[@]}" 'platform-tools' 'platforms;android-36' 'build-tools;36.0.0' 'ndk;28.2.13676358'
printf 'SDKs ready. Add %s/flutter/bin to PATH and set tool state variables from docs/DEVELOPMENT.md.\n' "$HIZ_TOOLCHAIN_DIR"
