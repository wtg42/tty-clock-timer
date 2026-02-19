#!/usr/bin/env bash
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

echo "[fetch-gum] downloading gum v${GUM_VERSION} (linux-x64)..."
curl -fsSL -o "${TMP_DIR}/${GUM_TARBALL}" "${GUM_URL}"

echo "[fetch-gum] verifying checksum..."
echo "${GUM_SHA256}  ${TMP_DIR}/${GUM_TARBALL}" | sha256sum --check --status

echo "[fetch-gum] extracting binary..."
tar -xzf "${TMP_DIR}/${GUM_TARBALL}" -C "${TMP_DIR}"

EXTRACTED_ROOT="${TMP_DIR}/gum_${GUM_VERSION}_Linux_x86_64"

if [[ ! -f "${EXTRACTED_ROOT}/gum" ]]; then
  echo "[error] gum binary missing in archive: ${GUM_TARBALL}" >&2
  exit 1
fi

install -m 0755 "${EXTRACTED_ROOT}/gum" "${GUM_BIN}"
echo "[fetch-gum] ready: ${GUM_BIN}"
