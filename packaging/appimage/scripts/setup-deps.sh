#!/usr/bin/env bash
# setup-deps.sh - 檢查並自動下載必要的依賴工具與套件
# 防呆機制：自動檢查 appimagetool、TUI 依賴是否完整
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"
TUI_SRC_DIR="${ROOT_DIR}/tui"

# 顏色定義（用於視覺化輸出）
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日誌函數
log_info() {
  echo -e "${BLUE}[setup-deps]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[setup-deps]${NC} ✓ $*"
}

log_warn() {
  echo -e "${YELLOW}[setup-deps]${NC} ⚠ $*"
}

log_error() {
  echo -e "${RED}[setup-deps]${NC} ✗ $*" >&2
}

# 檢查 appimagetool
check_appimagetool() {
  local appimagetool_bin=""

  if [[ -n "${APPIMAGETOOL_BIN:-}" && -x "${APPIMAGETOOL_BIN}" ]]; then
    log_success "appimagetool 已設定：${APPIMAGETOOL_BIN}"
    return 0
  fi

  if [[ -x "${ROOT_DIR}/packaging/tools/appimagetool.AppImage" ]]; then
    log_success "appimagetool 已存在（本機）"
    return 0
  fi

  if command -v appimagetool &>/dev/null; then
    log_success "appimagetool 已安裝（系統）"
    return 0
  fi

  log_warn "appimagetool 未找到，嘗試自動下載..."

  local appimage_version="1.9.1"
  local appimage_url="https://github.com/AppImage/appimagetool/releases/download/${appimage_version}/appimagetool-x86_64.AppImage"
  local appimage_path="${ROOT_DIR}/packaging/tools/appimagetool.AppImage"

  mkdir -p "$(dirname "${appimage_path}")"

  log_info "下載 appimagetool v${appimage_version}..."
  if curl -fsSL -o "${appimage_path}" "${appimage_url}"; then
    chmod +x "${appimage_path}"
    log_success "appimagetool 下載完成"
    return 0
  else
    log_error "appimagetool 下載失敗（URL: ${appimage_url}）"
    log_error "請手動下載：https://github.com/AppImage/appimagetool/releases"
    return 1
  fi
}

# 檢查 TUI 依賴
check_tui_deps() {
  if [[ ! -d "${TUI_SRC_DIR}" ]]; then
    log_error "TUI 源目錄不存在：${TUI_SRC_DIR}"
    return 1
  fi

  if [[ -d "${TUI_SRC_DIR}/node_modules" ]]; then
    log_success "TUI 依賴已安裝"
    return 0
  fi

  log_warn "TUI 依賴未安裝，執行 bun install..."

  if ! command -v bun &>/dev/null; then
    log_error "bun 未安裝，請先安裝：https://bun.sh"
    return 1
  fi

  if (cd "${TUI_SRC_DIR}" && bun install); then
    log_success "TUI 依賴安裝完成"
    return 0
  else
    log_error "TUI 依賴安裝失敗"
    return 1
  fi
}

# 主函數
main() {
  log_info "開始檢查依賴..."

  local failed=0

  check_appimagetool || ((failed++))
  check_tui_deps || ((failed++))

  if [[ ${failed} -gt 0 ]]; then
    log_error "有 ${failed} 個依賴檢查失敗"
    return 1
  fi

  log_success "所有依賴檢查通過 ✓"
  return 0
}

main "$@"
