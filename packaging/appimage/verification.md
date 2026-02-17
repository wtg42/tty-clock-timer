# MVP Verification Record

## Session

- Date: 2026-02-17
- Target: Linux x86_64
- Change: `appimage-packaging-foundation`

## Build and Package

- Core build: pass (`./packaging/appimage/scripts/build-core.sh`)
- AppImage package: pass (`APPIMAGE_VERSION=0.1.0 APPIMAGETOOL_BIN=.../packaging/tools/appimagetool.AppImage ./packaging/appimage/scripts/package-appimage.sh`)
- Artifact checklist script: pass (`APPIMAGE_VERSION=0.1.0 ./packaging/appimage/scripts/verify-artifact.sh`)

Produced artifact:

- Path: `packaging/out/appimage/tty-clock-timer-0.1.0-linux-x86_64.AppImage`
- SHA256: `5cd4adf3d01d3005246482ac25a2f74142e59948ebf019b8fb792bfe9b6bfd3d`

## Manual Acceptance (MVP)

- Timer flow: pass (`timer-smoke.ts` observed decrement then sent `quit`)
- Key commands (`p`/`r`/`s`/`q`): pass (`mvp-smoke.ts` command sequence all success)

## Known Limitations

- Current AppImage runtime still depends on host `bun` executable being available in `PATH`.
- `appimagetool` is not pinned in-repo; packaging currently expects external binary (`APPIMAGETOOL_BIN`) or system install.
- TUI runtime 由 `tui/dist/` bundle（`index.js` + `libopentui.so`）提供，驗證腳本需依 bundle 產物檢查。
