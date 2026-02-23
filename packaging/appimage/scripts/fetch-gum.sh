#!/usr/bin/env bash
# fetch-gum.sh - 下載並驗證 gum 工具二進檔
# 支援增量檢查：如果 gum 已存在且為可執行，則跳過下載
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"

GUM_VERSION="0.17.0"
GUM_TARBALL="gum_${GUM_VERSION}_Linux_x86_64.tar.gz"
GUM_URL="https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/${GUM_TARBALL}"
GUM_SHA256="69ee169bd6387331928864e94d47ed01ef649fbfe875baed1bbf27b5377a6fdb"

GUM_DIR="${ROOT_DIR}/packaging/tools/gum/linux-x64"
GUM_BIN="${GUM_DIR}/gum"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${GUM_DIR}"

# 檢查 gum 是否已存在且可執行
if [[ -f "${GUM_BIN}" && -x "${GUM_BIN}" ]]; then
  echo "[fetch-gum] gum 已存在，跳過下載：${GUM_BIN}"
  exit 0
fi

echo "[fetch-gum] downloading gum v${GUM_VERSION} (linux-x64)..."
if ! curl -fsSL -o "${TMP_DIR}/${GUM_TARBALL}" "${GUM_URL}"; then
  echo "[error] failed to download gum from: ${GUM_URL}" >&2
  echo "[error] 請檢查網路連接或訪問 https://github.com/charmbracelet/gum/releases" >&2
  exit 1
fi

echo "[fetch-gum] verifying checksum..."
if ! echo "${GUM_SHA256}  ${TMP_DIR}/${GUM_TARBALL}" | sha256sum --check --status; then
  echo "[error] checksum verification failed for: ${GUM_TARBALL}" >&2
  echo "[error] 檔案可能已損毀，請重新下載" >&2
  exit 1
fi

echo "[fetch-gum] extracting binary..."
tar -xzf "${TMP_DIR}/${GUM_TARBALL}" -C "${TMP_DIR}"

EXTRACTED_ROOT="${TMP_DIR}/gum_${GUM_VERSION}_Linux_x86_64"

if [[ ! -f "${EXTRACTED_ROOT}/gum" ]]; then
  echo "[error] gum binary missing in archive: ${GUM_TARBALL}" >&2
  echo "[error] 壓縮包結構可能已改變，請檢查上游版本" >&2
  exit 1
fi

install -m 0755 "${EXTRACTED_ROOT}/gum" "${GUM_BIN}"
echo "[fetch-gum] ✓ 成功安裝：${GUM_BIN}"
