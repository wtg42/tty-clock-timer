#!/usr/bin/env bash
# package-appimage.sh - 打包 AppImage 二進檔
# 防呆流程：自動檢查並下載必要依賴，然後進行編譯與打包
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"
OUT_DIR="${ROOT_DIR}/packaging/out/appimage"
STAGE_DIR="${OUT_DIR}/stage"
APPDIR="${OUT_DIR}/AppDir"
ASSETS_DIR="${ROOT_DIR}/packaging/appimage/assets"
TUI_SRC_DIR="${ROOT_DIR}/tui"
CORE_DIR="${ROOT_DIR}/core"

APPIMAGE_VERSION="${APPIMAGE_VERSION:-dev}"
APPIMAGE_NAME="tty-clock-timer-${APPIMAGE_VERSION}-linux-x86_64.AppImage"
APPIMAGE_PATH="${OUT_DIR}/${APPIMAGE_NAME}"

# 第一步：檢查與下載必要依賴
echo "[package-appimage] 檢查並下載依賴工具..."
if ! bash "${SCRIPT_DIR}/setup-deps.sh"; then
  echo "[error] 依賴檢查失敗，無法繼續打包" >&2
  exit 1
fi

# 決定使用哪個 appimagetool
if [[ -n "${APPIMAGETOOL_BIN:-}" ]]; then
  : # 使用者明確指定
elif [[ -x "${ROOT_DIR}/packaging/tools/appimagetool.AppImage" ]]; then
  APPIMAGETOOL_BIN="${ROOT_DIR}/packaging/tools/appimagetool.AppImage"
elif command -v appimagetool &>/dev/null; then
  APPIMAGETOOL_BIN="appimagetool"
else
  echo "[error] appimagetool 仍未找到，無法繼續" >&2
  exit 1
fi

# 第二步：清理舊的編譯產物
echo "[package-appimage] 清理舊的編譯產物..."
rm -rf "${STAGE_DIR}" \
       "${APPDIR}" \
       "${CORE_DIR}/zig-out" \
       "${CORE_DIR}/.zig-cache" \
       "${TUI_SRC_DIR}/dist"

# 第三步：編譯 Core 二進檔
echo "[package-appimage] 編譯 Core 二進檔..."
if ! "${SCRIPT_DIR}/build-core.sh"; then
  echo "[error] Core 編譯失敗" >&2
  exit 1
fi

# 第四步：編譯 TUI bundle
echo "[package-appimage] 編譯 TUI bundle..."
if ! (cd "${TUI_SRC_DIR}" && bun run build); then
  echo "[error] TUI 編譯失敗" >&2
  exit 1
fi

PROMPT_HELPER_SRC="${TUI_SRC_DIR}/dist/prompts/helper.js"
if [[ ! -f "${PROMPT_HELPER_SRC}" ]]; then
  echo "[error] Prompt helper 編譯輸出不存在：${PROMPT_HELPER_SRC}" >&2
  exit 1
fi

# 第五步：組裝 AppDir 結構
echo "[package-appimage] 組裝 AppDir 結構..."
install -d "${APPDIR}/usr/bin"
install -d "${APPDIR}/usr/lib/tty-clock-timer/tui"
install -d "${APPDIR}/usr/share/applications"
install -d "${APPDIR}/usr/share/icons/hicolor/scalable/apps"

# 安裝二進檔與資源
if [[ ! -f "${STAGE_DIR}/usr/bin/tic" ]]; then
  echo "[error] Core 二進檔不存在：${STAGE_DIR}/usr/bin/tic" >&2
  exit 1
fi

if [[ ! -d "${TUI_SRC_DIR}/dist" ]]; then
  echo "[error] TUI 編譯輸出不存在：${TUI_SRC_DIR}/dist" >&2
  exit 1
fi

install -m 0755 "${STAGE_DIR}/usr/bin/tic" "${APPDIR}/usr/bin/tic"
cp -R "${TUI_SRC_DIR}/dist/." "${APPDIR}/usr/lib/tty-clock-timer/tui/"

install -m 0644 "${ASSETS_DIR}/tty-clock-timer.desktop" "${APPDIR}/usr/share/applications/tty-clock-timer.desktop"
install -m 0644 "${ASSETS_DIR}/tty-clock-timer.svg" "${APPDIR}/usr/share/icons/hicolor/scalable/apps/tty-clock-timer.svg"

ln -sf "usr/share/applications/tty-clock-timer.desktop" "${APPDIR}/tty-clock-timer.desktop"
ln -sf "usr/share/icons/hicolor/scalable/apps/tty-clock-timer.svg" "${APPDIR}/tty-clock-timer.svg"

# 第六步：生成 AppRun 啟動器
echo "[package-appimage] 生成 AppRun 啟動器..."
cat > "${APPDIR}/AppRun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

APPDIR="$(cd -- "$(dirname -- "$0")" && pwd)"
export TTY_CLOCK_TUI_CWD="${TTY_CLOCK_TUI_CWD:-${APPDIR}/usr/lib/tty-clock-timer/tui}"
export TTY_CLOCK_TUI_ENTRY="${TTY_CLOCK_TUI_ENTRY:-index.js}"

exec "${APPDIR}/usr/bin/tic" "$@"
EOF
chmod 0755 "${APPDIR}/AppRun"

# 第七步：打包成 AppImage
echo "[package-appimage] 使用 appimagetool 打包..."
if [[ ! -x "${APPIMAGETOOL_BIN}" ]]; then
  echo "[error] appimagetool 不可執行：${APPIMAGETOOL_BIN}" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"
ARCH=x86_64 "${APPIMAGETOOL_BIN}" "${APPDIR}" "${APPIMAGE_PATH}"
chmod 0755 "${APPIMAGE_PATH}"

# 驗證 AppImage 是否成功生成
if [[ ! -f "${APPIMAGE_PATH}" ]]; then
  echo "[error] AppImage 生成失敗" >&2
  exit 1
fi

echo ""
echo "=========================================="
echo "✓ AppImage 打包完成"
echo "=========================================="
echo "文件路徑：${APPIMAGE_PATH}"
echo "文件大小：$(du -h "${APPIMAGE_PATH}" | cut -f1)"
echo ""
echo "下一步：運行驗證"
echo "  APPIMAGE_VERSION=${APPIMAGE_VERSION} bash ${SCRIPT_DIR}/verify-artifact.sh"
echo "=========================================="
