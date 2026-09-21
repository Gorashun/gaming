#!/usr/bin/env bash
# Prepare a headless machine (CI runner or a fresh container) for
# `godot --headless --export-debug "Android Debug"`.
#
# Godot's Android exporter reads three things from the EDITOR settings, not
# from the project or the export preset:
#
#   export/android/android_sdk_path   where apksigner and zipalign live
#   export/android/java_sdk_path      the JDK that apksigner runs on
#   export/android/debug_keystore     the key every debug APK is signed with
#
# On a developer machine the editor writes those itself. Headless there is no
# editor session, so this script writes the settings file by hand and creates
# the debug keystore with keytool.
#
# The keystore is created in-place and is NEVER committed: .gitignore blocks
# *.keystore and *.jks, and the alias/password below are Android's well known
# public debug values, not a secret.
#
# Usage:
#   tools/godot_editor_settings.sh [--keystore PATH] [--sdk PATH] [--jdk PATH]
#
# Defaults: keystore ~/.android/debug.keystore, SDK $ANDROID_HOME (or
# $ANDROID_SDK_ROOT), JDK $JAVA_HOME (or the parent of `which java`).

set -euo pipefail

GODOT_MINOR="${GODOT_MINOR:-4.6}"
KEYSTORE="${HOME}/.android/debug.keystore"
SDK_PATH="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
JDK_PATH="${JAVA_HOME:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keystore) KEYSTORE="$2"; shift 2 ;;
    --sdk) SDK_PATH="$2"; shift 2 ;;
    --jdk) JDK_PATH="$2"; shift 2 ;;
    --godot-minor) GODOT_MINOR="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# Fall back to the JDK that owns the `java` on PATH. readlink -f resolves the
# /usr/bin/java -> .../jre/bin/java symlink chain; Godot wants the directory
# that has bin/java under it, hence two dirname steps.
if [[ -z "${JDK_PATH}" ]] && command -v java >/dev/null 2>&1; then
  JDK_PATH="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
fi

# --- Debug keystore -------------------------------------------------------
# Alias androiddebugkey / password android are the values the Android tooling
# has used since 2009. apksigner refuses anything shorter than 6 characters,
# and Godot hardcodes nothing: user and password come from the settings below.
if [[ ! -f "${KEYSTORE}" ]]; then
  mkdir -p "$(dirname "${KEYSTORE}")"
  keytool -genkeypair \
    -keystore "${KEYSTORE}" \
    -storepass android \
    -alias androiddebugkey \
    -keypass android \
    -dname "CN=PIPWRECK Debug, OU=dev, O=PIPWRECK, L=Stockholm, S=Stockholm, C=SE" \
    -validity 10950 \
    -keyalg RSA \
    -keysize 2048 \
    -storetype pkcs12 >/dev/null
  echo "created debug keystore: ${KEYSTORE}"
else
  echo "debug keystore already present: ${KEYSTORE}"
fi

# --- Editor settings ------------------------------------------------------
# Godot 4 looks for editor_settings-<major>.<minor>.tres under the editor
# config dir ($XDG_CONFIG_HOME/godot on Linux). A .tres with only the keys we
# care about is fine: everything else falls back to its built-in default.
CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/godot"
SETTINGS_FILE="${CONFIG_DIR}/editor_settings-${GODOT_MINOR}.tres"
mkdir -p "${CONFIG_DIR}"

{
  echo '[gd_resource type="EditorSettings" format=3]'
  echo
  echo '[resource]'
  echo "export/android/debug_keystore = \"${KEYSTORE}\""
  echo 'export/android/debug_keystore_user = "androiddebugkey"'
  echo 'export/android/debug_keystore_pass = "android"'
  # Godot 4.6 kraschar (SIGSEGV i pthread_mutex_lock) vid avslut av en
  # headless-export när den försöker stänga en adb-daemon som inte finns.
  # Exporten är då redan klar och signerad; den här raden stoppar avslutet
  # från att röra adb över huvud taget.
  echo 'export/android/shutdown_adb_on_exit = false'
  if [[ -n "${SDK_PATH}" ]]; then
    echo "export/android/android_sdk_path = \"${SDK_PATH}\""
  fi
  if [[ -n "${JDK_PATH}" ]]; then
    echo "export/android/java_sdk_path = \"${JDK_PATH}\""
  fi
} > "${SETTINGS_FILE}"

echo "wrote ${SETTINGS_FILE}"
echo "  android_sdk_path = ${SDK_PATH:-<unset>}"
echo "  java_sdk_path    = ${JDK_PATH:-<unset>}"
