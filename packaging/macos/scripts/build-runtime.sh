#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"
CORE_DIR="${ROOT_DIR}/core"
TUI_DIR="${ROOT_DIR}/tui"
OUT_DIR="${ROOT_DIR}/packaging/out/macos"

MACOS_VERSION="${MACOS_VERSION:-dev}"
ARCHIVE_ROOT_NAME="tty-clock-timer-${MACOS_VERSION}-macos-arm64"
STAGE_ROOT="${OUT_DIR}/stage/${ARCHIVE_ROOT_NAME}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Error: macOS packaging requires Darwin." >&2
  exit 1
fi
if [[ "$(uname -m)" != "arm64" ]]; then
  echo "Error: macOS MVP packaging requires arm64; found $(uname -m)." >&2
  exit 1
fi
for command_name in zig bun; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Error: Required build tool is unavailable: ${command_name}" >&2
    exit 1
  fi
done

rm -rf "${OUT_DIR}/stage"
mkdir -p "${STAGE_ROOT}/bin"
mkdir -p "${STAGE_ROOT}/libexec/tty-clock-timer"
mkdir -p "${STAGE_ROOT}/lib/tty-clock-timer/tui"

(cd "${CORE_DIR}" && zig build -Doptimize=ReleaseSafe)
(cd "${TUI_DIR}" && bun run build)

install -m 0755 "${CORE_DIR}/zig-out/bin/ttc" "${STAGE_ROOT}/libexec/tty-clock-timer/ttc"
install -m 0755 "${ROOT_DIR}/packaging/macos/assets/ttc" "${STAGE_ROOT}/bin/ttc"
cp -R "${TUI_DIR}/dist/." "${STAGE_ROOT}/lib/tty-clock-timer/tui/"

"${SCRIPT_DIR}/verify-stage.sh" "${STAGE_ROOT}"
echo "${STAGE_ROOT}"

