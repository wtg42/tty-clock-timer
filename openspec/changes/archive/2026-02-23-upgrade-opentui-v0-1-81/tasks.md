## 1. 升級依賴版本

- [x] 1.1 修改 `tui/package.json`：將 `@opentui/core` 與 `@opentui/solid` 從 `^0.1.80` 更新為 `^0.1.81`
- [x] 1.2 在 `tui/` 目錄執行 `bun install` 更新 lockfile

## 2. 驗證

- [x] 2.1 執行 `bun run build` 確認 bundle build 成功
- [x] 2.2 執行 `zig build run -- --minutes 1` 確認 TUI 可正常啟動與顯示
