## 1. 依賴與鎖檔整理

- [x] 1.1 將 `tui/package.json` 內 `@opentui/core`、`@opentui/solid` 更新為最新穩定版本（目前 `0.1.84`）
- [x] 1.2 使用 Bun 重新解析依賴並刷新 `tui/bun.lock`，確認 lockfile 內容與版本一致
- [x] 1.3 移除 `tui/package-lock.json`，並確認 `tui/` 僅保留 `bun.lock` 作為 lockfile

## 2. 流程與驗證

- [x] 2.1 在專案文件補充 `tui/` 的 Bun-only 套件管理規範（避免重新產生 npm lockfile）
- [x] 2.2 在 `tui/` 執行 `bun install`、`bun run build`、`bun test`，確認升級後可安裝、可建置、可測試
- [x] 2.3 檢查變更內容，確認未引入與本次依賴治理無關的功能修改
