#!/usr/bin/env bash
# build-core.sh - 編譯 Zig Core 二進檔
# 防呆檢查：驗證編譯成功、二進檔存在、可執行
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"
CORE_DIR="${ROOT_DIR}/core"
OUT_DIR="${ROOT_DIR}/packaging/out/appimage"
STAGE_DIR="${OUT_DIR}/stage"

TARGET="x86_64-linux"
OPTIMIZE="ReleaseSafe"
CORE_BINARY="${CORE_DIR}/zig-out/bin/tic"
STAGED_BINARY="${STAGE_DIR}/usr/bin/tic"

echo "[build-core] 編譯設定：target=${TARGET}, optimize=${OPTIMIZE}"

# 檢查 zig 是否安裝
if ! command -v zig &>/dev/null; then
  echo "[error] zig 未安裝" >&2
  echo "[error] 請訪問 https://ziglang.org/download 安裝 Zig" >&2
  exit 1
fi

# 編譯
echo "[build-core] 正在編譯..."
if ! (cd "${CORE_DIR}" && zig build -Dtarget="${TARGET}" -Doptimize="${OPTIMIZE}"); then
  echo "[error] 編譯失敗，請檢查 Core 源代碼" >&2
  exit 1
fi

# 驗證編譯輸出
if [[ ! -f "${CORE_BINARY}" ]]; then
  echo "[error] 編譯二進檔不存在：${CORE_BINARY}" >&2
  exit 1
fi

if [[ ! -x "${CORE_BINARY}" ]]; then
  echo "[error] 編譯二進檔不可執行：${CORE_BINARY}" >&2
  exit 1
fi

# 複製到 stage 目錄
install -d "${STAGE_DIR}/usr/bin"
install -m 0755 "${CORE_BINARY}" "${STAGED_BINARY}"

echo "[build-core] ✓ 編譯成功：${STAGED_BINARY}"
