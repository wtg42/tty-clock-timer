#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"
OUT_DIR="${ROOT_DIR}/packaging/out/appimage"
APPDIR="${OUT_DIR}/AppDir"

APPIMAGE_VERSION="${APPIMAGE_VERSION:-dev}"
APPIMAGE_NAME="tty-clock-timer-${APPIMAGE_VERSION}-linux-x86_64.AppImage"
APPIMAGE_PATH="${OUT_DIR}/${APPIMAGE_NAME}"

status=0

check_exists() {
  local path="$1"
  local label="$2"
  if [[ -e "${path}" ]]; then
    echo "[ok] ${label}: ${path}"
  else
    echo "[fail] ${label}: ${path}"
    status=1
  fi
}

check_executable() {
  local path="$1"
  local label="$2"
  if [[ -x "${path}" ]]; then
    echo "[ok] ${label}: executable"
  else
    echo "[fail] ${label}: not executable"
    status=1
  fi
}

if [[ "$(basename -- "${APPIMAGE_PATH}")" =~ ^tty-clock-timer-[A-Za-z0-9._-]+-linux-x86_64\.AppImage$ ]]; then
  echo "[ok] artifact naming"
else
  echo "[fail] artifact naming"
  status=1
fi

check_exists "${APPIMAGE_PATH}" "AppImage file"
check_executable "${APPIMAGE_PATH}" "AppImage file"

check_exists "${APPDIR}/AppRun" "AppRun"
check_executable "${APPDIR}/AppRun" "AppRun"

check_exists "${APPDIR}/usr/bin/tty_clock_timer" "core binary"
check_executable "${APPDIR}/usr/bin/tty_clock_timer" "core binary"

check_exists "${APPDIR}/usr/lib/tty-clock-timer/tui/index.js" "TUI runtime entry"
check_exists "${APPDIR}/usr/lib/tty-clock-timer/tui/libopentui.so" "TUI native library"
check_exists "${APPDIR}/usr/share/applications/tty-clock-timer.desktop" "desktop file"
check_exists "${APPDIR}/usr/share/icons/hicolor/scalable/apps/tty-clock-timer.svg" "icon"

exit "${status}"
