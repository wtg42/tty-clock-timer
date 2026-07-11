#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  echo "Usage: verify-stage.sh <archive-root>" >&2
  exit 2
fi

ARCHIVE_ROOT="$1"
status=0

check_file() {
  local path="$1"
  local label="$2"
  if [[ -f "${path}" ]]; then
    echo "[ok] ${label}: ${path}"
  else
    echo "[fail] missing ${label}: ${path}" >&2
    status=1
  fi
}

check_executable() {
  local path="$1"
  local label="$2"
  if [[ -x "${path}" ]]; then
    echo "[ok] ${label}: executable"
  else
    echo "[fail] ${label} is not executable: ${path}" >&2
    status=1
  fi
}

check_file "${ARCHIVE_ROOT}/bin/ttc" "launcher"
check_executable "${ARCHIVE_ROOT}/bin/ttc" "launcher"
check_file "${ARCHIVE_ROOT}/libexec/tty-clock-timer/ttc" "Zig core"
check_executable "${ARCHIVE_ROOT}/libexec/tty-clock-timer/ttc" "Zig core"
check_file "${ARCHIVE_ROOT}/lib/tty-clock-timer/tui/index.js" "TUI bundle"
check_file "${ARCHIVE_ROOT}/lib/tty-clock-timer/tui/prompts/helper.js" "prompt helper"
check_file "${ARCHIVE_ROOT}/lib/tty-clock-timer/tui/libopentui.dylib" "OpenTUI native library"
check_file "${ARCHIVE_ROOT}/lib/tty-clock-timer/tui/node_modules/@opentui/core-darwin-arm64/index.ts" "Darwin arm64 shim"

exit "${status}"

