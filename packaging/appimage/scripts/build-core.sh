#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"
CORE_DIR="${ROOT_DIR}/core"
OUT_DIR="${ROOT_DIR}/packaging/out/appimage"
STAGE_DIR="${OUT_DIR}/stage"

TARGET="x86_64-linux"
OPTIMIZE="ReleaseSafe"
CORE_BINARY="${CORE_DIR}/zig-out/bin/tty_clock_timer"
STAGED_BINARY="${STAGE_DIR}/usr/bin/tty_clock_timer"

echo "[build-core] target=${TARGET} optimize=${OPTIMIZE}"
(cd "${CORE_DIR}" && zig build -Dtarget="${TARGET}" -Doptimize="${OPTIMIZE}")

install -d "${STAGE_DIR}/usr/bin"
install -m 0755 "${CORE_BINARY}" "${STAGED_BINARY}"

echo "[build-core] staged binary: ${STAGED_BINARY}"
