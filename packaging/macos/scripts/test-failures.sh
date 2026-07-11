#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"
OUT_DIR="${ROOT_DIR}/packaging/out/macos"

MACOS_VERSION="${MACOS_VERSION:-dev}"
ARCHIVE_ROOT_NAME="tty-clock-timer-${MACOS_VERSION}-macos-arm64"
ARCHIVE_PATH="${OUT_DIR}/${ARCHIVE_ROOT_NAME}.tar.gz"

if [[ ! -f "${ARCHIVE_PATH}" ]]; then
  echo "Error: Package the macOS artifact before running failure tests." >&2
  exit 1
fi

TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ttc-macos-failures.XXXXXX")"
trap 'rm -rf "${TEST_DIR}"' EXIT
tar -xzf "${ARCHIVE_PATH}" -C "${TEST_DIR}"
ARCHIVE_ROOT="${TEST_DIR}/${ARCHIVE_ROOT_NAME}"

set +e
bun_output="$(PATH=/usr/bin:/bin "${ARCHIVE_ROOT}/bin/ttc" --seconds 1 2>&1)"
bun_status=$?
set -e
if [[ "${bun_status}" -eq 0 || "${bun_output}" != *"Bun is required"* ]]; then
  echo "Error: Launcher did not diagnose a missing Bun prerequisite." >&2
  exit 1
fi

rm "${ARCHIVE_ROOT}/lib/tty-clock-timer/tui/libopentui.dylib"
set +e
missing_output="$("${SCRIPT_DIR}/verify-stage.sh" "${ARCHIVE_ROOT}" 2>&1)"
missing_status=$?
set -e
if [[ "${missing_status}" -eq 0 || "${missing_output}" != *"OpenTUI native library"* ]]; then
  echo "Error: Stage verifier did not diagnose a missing native library." >&2
  exit 1
fi

echo "macOS packaging failure tests passed"
