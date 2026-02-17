## Why

目前 AppImage 打包腳本直接 `cp -R tui/` 將整個 TUI 原始碼目錄複製進 AppDir，導致 `node_modules`（~186MB）一併打包，而實際原始碼僅 44KB。透過 `bun build` 搭配 `@opentui/solid/bun-plugin` 在建置時完成 JSX/Solid 轉換並 bundle 所有 JS 依賴，可將 TUI 部分從 ~186MB 縮減至 ~5MB（bundle + `libopentui.so`）。

## What Changes

- 新增 TUI build script，使用 `Bun.build()` + `solidTransformPlugin` 將 `src/index.tsx` 打包為單一 JS bundle
- 修改 `package-appimage.sh`，改為複製 build 產物（bundle + `libopentui.so`）而非整個 `tui/` 目錄
- 調整 `AppRun` 中的 `TTY_CLOCK_TUI_ENTRY` 指向 bundled JS 檔案
- `@opentui/core-linux-x64/libopentui.so` 作為外部檔案單獨複製（bun:ffi native binding 無法 inline）

## Capabilities

### New Capabilities
- `tui-bundle-build`: 定義 TUI 的 bun build 流程，包含 Solid plugin 整合、external native binding 處理、產物規格

### Modified Capabilities
- `appimage-packaging-workflow`: 打包腳本改為使用 build 產物而非原始碼目錄
- `core-tui-artifact-contract`: TUI artifact 從原始碼目錄變為 bundle + .so，入口路徑與結構改變

## Impact

- `tui/`：新增 build script（如 `tui/build.ts`）
- `packaging/appimage/scripts/package-appimage.sh`：TUI 複製邏輯重寫
- `packaging/appimage/scripts/package-appimage.sh` 內的 `AppRun`：環境變數調整
- AppImage 產物大小：預估從 ~190MB 降至 ~10MB
