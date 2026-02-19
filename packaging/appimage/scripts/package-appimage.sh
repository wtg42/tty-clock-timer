#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"
OUT_DIR="${ROOT_DIR}/packaging/out/appimage"
STAGE_DIR="${OUT_DIR}/stage"
APPDIR="${OUT_DIR}/AppDir"
ASSETS_DIR="${ROOT_DIR}/packaging/appimage/assets"
TUI_SRC_DIR="${ROOT_DIR}/tui"
CORE_DIR="${ROOT_DIR}/core"
GUM_SRC="${ROOT_DIR}/packaging/tools/gum/linux-x64/gum"

APPIMAGE_VERSION="${APPIMAGE_VERSION:-dev}"
APPIMAGE_NAME="tty-clock-timer-${APPIMAGE_VERSION}-linux-x86_64.AppImage"

if [[ -n "${APPIMAGETOOL_BIN:-}" ]]; then
  : # 使用者明確指定
elif [[ -x "${ROOT_DIR}/packaging/tools/appimagetool.AppImage" ]]; then
  APPIMAGETOOL_BIN="${ROOT_DIR}/packaging/tools/appimagetool.AppImage"
elif command -v appimagetool &>/dev/null; then
  APPIMAGETOOL_BIN="appimagetool"
else
  echo "[error] appimagetool not found." >&2
  echo "  Option 1: Place it at packaging/tools/appimagetool.AppImage" >&2
  echo "  Option 2: Set APPIMAGETOOL_BIN=/path/to/appimagetool" >&2
  echo "  Download: https://github.com/AppImage/appimagetool/releases" >&2
  exit 1
fi
APPIMAGE_PATH="${OUT_DIR}/${APPIMAGE_NAME}"

echo "[package-appimage] Cleaning repo-local build artifacts..."
rm -rf "${STAGE_DIR}" \
       "${APPDIR}" \
       "${CORE_DIR}/zig-out" \
       "${CORE_DIR}/.zig-cache" \
       "${TUI_SRC_DIR}/dist"

echo "[package-appimage] Rebuilding core binary..."
"${SCRIPT_DIR}/build-core.sh"

if [[ ! -f "${GUM_SRC}" ]]; then
  echo "[error] bundled gum not found: ${GUM_SRC}" >&2
  exit 1
fi

if [[ ! -x "${GUM_SRC}" ]]; then
  echo "[error] bundled gum is not executable: ${GUM_SRC}" >&2
  exit 1
fi

# Build TUI bundle (replaces copying raw source + node_modules)
echo "[package-appimage] Building TUI bundle..."
(cd "${TUI_SRC_DIR}" && bun run build)

install -d "${APPDIR}/usr/bin"
install -d "${APPDIR}/usr/lib/tty-clock-timer/tui"
install -d "${APPDIR}/usr/lib/tty-clock-timer/tools/gum/linux-x64"
install -d "${APPDIR}/usr/share/applications"
install -d "${APPDIR}/usr/share/icons/hicolor/scalable/apps"

install -m 0755 "${STAGE_DIR}/usr/bin/tty_clock_timer" "${APPDIR}/usr/bin/tty_clock_timer"
cp -R "${TUI_SRC_DIR}/dist/." "${APPDIR}/usr/lib/tty-clock-timer/tui/"
install -m 0755 "${GUM_SRC}" "${APPDIR}/usr/lib/tty-clock-timer/tools/gum/linux-x64/gum"

install -m 0644 "${ASSETS_DIR}/tty-clock-timer.desktop" "${APPDIR}/usr/share/applications/tty-clock-timer.desktop"
install -m 0644 "${ASSETS_DIR}/tty-clock-timer.svg" "${APPDIR}/usr/share/icons/hicolor/scalable/apps/tty-clock-timer.svg"

ln -sf "usr/share/applications/tty-clock-timer.desktop" "${APPDIR}/tty-clock-timer.desktop"
ln -sf "usr/share/icons/hicolor/scalable/apps/tty-clock-timer.svg" "${APPDIR}/tty-clock-timer.svg"

cat > "${APPDIR}/AppRun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

APPDIR="$(cd -- "$(dirname -- "$0")" && pwd)"
export TTY_CLOCK_TUI_CWD="${TTY_CLOCK_TUI_CWD:-${APPDIR}/usr/lib/tty-clock-timer/tui}"
export TTY_CLOCK_TUI_ENTRY="${TTY_CLOCK_TUI_ENTRY:-index.js}"
export TTY_CLOCK_GUM_BIN="${TTY_CLOCK_GUM_BIN:-${APPDIR}/usr/lib/tty-clock-timer/tools/gum/linux-x64/gum}"

exec "${APPDIR}/usr/bin/tty_clock_timer" "$@"
EOF
chmod 0755 "${APPDIR}/AppRun"

ARCH=x86_64 "${APPIMAGETOOL_BIN}" "${APPDIR}" "${APPIMAGE_PATH}"
chmod 0755 "${APPIMAGE_PATH}"

echo "[package-appimage] artifact: ${APPIMAGE_PATH}"
