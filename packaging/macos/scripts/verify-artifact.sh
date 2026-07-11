#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"
OUT_DIR="${ROOT_DIR}/packaging/out/macos"

MACOS_VERSION="${MACOS_VERSION:-dev}"
ARCHIVE_ROOT_NAME="tty-clock-timer-${MACOS_VERSION}-macos-arm64"
ARCHIVE_NAME="${ARCHIVE_ROOT_NAME}.tar.gz"
ARCHIVE_PATH="${OUT_DIR}/${ARCHIVE_NAME}"
CHECKSUM_PATH="${ARCHIVE_PATH}.sha256"

if [[ ! "${ARCHIVE_NAME}" =~ ^tty-clock-timer-[A-Za-z0-9._+-]+-macos-arm64\.tar\.gz$ ]]; then
  echo "Error: Invalid macOS artifact name: ${ARCHIVE_NAME}" >&2
  exit 1
fi
for path in "${ARCHIVE_PATH}" "${CHECKSUM_PATH}"; do
  if [[ ! -f "${path}" ]]; then
    echo "Error: Missing macOS release artifact: ${path}" >&2
    exit 1
  fi
done
if ! command -v bun >/dev/null 2>&1; then
  echo "Error: Bun is required for macOS artifact smoke verification." >&2
  exit 1
fi

(cd "${OUT_DIR}" && shasum -a 256 -c "${ARCHIVE_NAME}.sha256")

VERIFY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ttc-macos-verify.XXXXXX")"
trap 'rm -rf "${VERIFY_DIR}"' EXIT
tar -xzf "${ARCHIVE_PATH}" -C "${VERIFY_DIR}"
ARCHIVE_ROOT="${VERIFY_DIR}/${ARCHIVE_ROOT_NAME}"

"${SCRIPT_DIR}/verify-stage.sh" "${ARCHIVE_ROOT}"

(
  cd "${VERIFY_DIR}"
  TTC_MACOS_RUNTIME_ROOT="${ARCHIVE_ROOT}" \
    TTY_CLOCK_TUI_CWD="${SCRIPT_DIR}" \
    TTY_CLOCK_TUI_ENTRY="runtime-smoke.ts" \
    "${ARCHIVE_ROOT}/bin/ttc" --seconds 5
)

echo "macOS artifact verification passed: ${ARCHIVE_PATH}"

