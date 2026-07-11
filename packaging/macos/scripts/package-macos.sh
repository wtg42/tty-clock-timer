#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"
OUT_DIR="${ROOT_DIR}/packaging/out/macos"

MACOS_VERSION="${MACOS_VERSION:-dev}"
ARCHIVE_ROOT_NAME="tty-clock-timer-${MACOS_VERSION}-macos-arm64"
STAGE_ROOT="${OUT_DIR}/stage/${ARCHIVE_ROOT_NAME}"
ARCHIVE_NAME="${ARCHIVE_ROOT_NAME}.tar.gz"
ARCHIVE_PATH="${OUT_DIR}/${ARCHIVE_NAME}"
CHECKSUM_PATH="${ARCHIVE_PATH}.sha256"

"${SCRIPT_DIR}/build-runtime.sh" >/dev/null
rm -f "${ARCHIVE_PATH}" "${CHECKSUM_PATH}"

(cd "${OUT_DIR}/stage" && COPYFILE_DISABLE=1 tar -czf "${ARCHIVE_PATH}" "${ARCHIVE_ROOT_NAME}")
(cd "${OUT_DIR}" && shasum -a 256 "${ARCHIVE_NAME}" > "${ARCHIVE_NAME}.sha256")

echo "Created ${ARCHIVE_PATH}"
echo "Created ${CHECKSUM_PATH}"

