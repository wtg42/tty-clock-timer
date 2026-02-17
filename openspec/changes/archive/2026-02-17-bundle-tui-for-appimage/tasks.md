## 1. TUI Build Script

- [x] 1.1 建立 `tui/build.ts`：使用 `Bun.build()` + `@opentui/solid/bun-plugin` 將 `src/index.tsx` 打包為單一 bundle，輸出至 `tui/dist/`
- [x] 1.2 處理 `libopentui.so`：build script 將 `.so` 從 `node_modules/@opentui/core-linux-x64/` 複製至 `tui/dist/`
- [x] 1.3 在 `tui/package.json` 加入 `"build"` script
- [x] 1.4 驗證 bundle 可在無 `node_modules` 環境下由 `bun` 正常執行

## 2. 打包腳本更新

- [x] 2.1 修改 `package-appimage.sh`：執行 `bun run build` 取代 `cp -R tui/`
- [x] 2.2 修改 `package-appimage.sh`：複製 `tui/dist/` 內容至 AppDir（取代整個 tui 目錄）
- [x] 2.3 更新 `AppRun` 的 `TTY_CLOCK_TUI_CWD` 與 `TTY_CLOCK_TUI_ENTRY` 指向 bundle 產物

## 3. 驗證

- [x] 3.1 執行完整 AppImage 打包流程，確認產物不含 `node_modules`
- [x] 3.2 執行 AppImage，驗證 timer 啟動與 key commands 正常運作
