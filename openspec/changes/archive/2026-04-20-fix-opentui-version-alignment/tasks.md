## 1. 依賴與匯入路徑對齊

- [x] 1.1 更新 `tui/package.json` 中的 `@opentui/core`、`@opentui/solid` 與必要 peer 依賴版本，確保 OpenTUI 套件對齊到同一批相容版本
- [x] 1.2 重新產生並檢查 `tui/bun.lock`，確認安裝樹不再同時包含多份版本不同的 `@opentui/core`
- [x] 1.3 調整 TUI 原始碼匯入路徑，避免應用程式層額外直接拉入第二條 `@opentui/core` module graph

## 2. Bundle 與 runtime 修正

- [x] 2.1 視需要調整 `tui/build.ts` 或相關 bundle 設定，確保 `tui/dist/index.js` 僅包含單一 OpenTUI core 初始化路徑
- [x] 2.2 驗證 `tui/dist/` 與最小 native shim 仍符合既有 artifact contract，且不因版本對齊破壞 bundle 啟動

## 3. 驗證與 packaged smoke test

- [x] 3.1 執行 `bun install`、`bun run build`、`bun test`，確認 OpenTUI 升級後最小自動化驗證通過
- [x] 3.2 重新執行 AppImage 打包與 runtime smoke test，確認 packaged TUI 啟動時不再出現 duplicate env registry registration error
