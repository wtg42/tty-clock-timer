#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"
OUT_DIR="${ROOT_DIR}/packaging/out/appimage"
STAGE_DIR="${OUT_DIR}/stage"
APPDIR="${OUT_DIR}/AppDir"
ASSETS_DIR="${ROOT_DIR}/packaging/appimage/assets"
TUI_SRC_DIR="${ROOT_DIR}/tui"

APPIMAGE_VERSION="${APPIMAGE_VERSION:-dev}"
APPIMAGETOOL_BIN="${APPIMAGETOOL_BIN:-appimagetool}"
APPIMAGE_NAME="tty-clock-timer-${APPIMAGE_VERSION}-linux-x86_64.AppImage"
APPIMAGE_PATH="${OUT_DIR}/${APPIMAGE_NAME}"

if [[ ! -x "${STAGE_DIR}/usr/bin/tty_clock_timer" ]]; then
  "${SCRIPT_DIR}/build-core.sh"
fi

rm -rf "${APPDIR}"
install -d "${APPDIR}/usr/bin"
install -d "${APPDIR}/usr/lib/tty-clock-timer"
install -d "${APPDIR}/usr/share/applications"
install -d "${APPDIR}/usr/share/icons/hicolor/scalable/apps"

install -m 0755 "${STAGE_DIR}/usr/bin/tty_clock_timer" "${APPDIR}/usr/bin/tty_clock_timer"
cp -R "${TUI_SRC_DIR}" "${APPDIR}/usr/lib/tty-clock-timer/tui"

install -m 0644 "${ASSETS_DIR}/tty-clock-timer.desktop" "${APPDIR}/usr/share/applications/tty-clock-timer.desktop"
install -m 0644 "${ASSETS_DIR}/tty-clock-timer.svg" "${APPDIR}/usr/share/icons/hicolor/scalable/apps/tty-clock-timer.svg"

ln -sf "usr/share/applications/tty-clock-timer.desktop" "${APPDIR}/tty-clock-timer.desktop"
ln -sf "usr/share/icons/hicolor/scalable/apps/tty-clock-timer.svg" "${APPDIR}/tty-clock-timer.svg"

cat > "${APPDIR}/AppRun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

APPDIR="$(cd -- "$(dirname -- "$0")" && pwd)"
export TTY_CLOCK_TUI_CWD="${TTY_CLOCK_TUI_CWD:-${APPDIR}/usr/lib/tty-clock-timer/tui}"
export TTY_CLOCK_TUI_ENTRY="${TTY_CLOCK_TUI_ENTRY:-src/index.tsx}"

exec "${APPDIR}/usr/bin/tty_clock_timer" "$@"
EOF
chmod 0755 "${APPDIR}/AppRun"

ARCH=x86_64 "${APPIMAGETOOL_BIN}" "${APPDIR}" "${APPIMAGE_PATH}"
chmod 0755 "${APPIMAGE_PATH}"

echo "[package-appimage] artifact: ${APPIMAGE_PATH}"
