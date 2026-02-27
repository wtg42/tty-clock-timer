## Why

目前 `tui/` 專案同時存在 `bun.lock` 與 `package-lock.json`，造成依賴版本來源不一致，容易在本機與 CI 出現不可預期差異。OpenTUI 屬於 `0.x` 快速迭代階段，若不建立明確更新與鎖檔策略，將提高後續升級與除錯成本。

## What Changes

- 將 `@opentui/core` 與 `@opentui/solid` 更新至最新穩定版本（目前為 `0.1.84`）。
- 明確定義 `tui/` 以 Bun 作為單一套件管理工具，`bun.lock` 為唯一 lockfile。
- 移除 `tui/package-lock.json`，避免 npm 鎖檔與 Bun 鎖檔長期漂移。
- 補充依賴維護與驗證流程，確保後續可持續追蹤 OpenTUI 更新。

## Capabilities

### New Capabilities
- `tui-dependency-lockfile-management`: 定義 TUI 依賴升級、鎖檔治理與驗證規則，確保 Bun-only 工作流一致性。

### Modified Capabilities
- 無

## Impact

- 影響目錄：`tui/`（依賴版本、lockfile、相關文件/流程）。
- 影響套件：`@opentui/core`、`@opentui/solid`。
- 影響開發流程：統一使用 Bun 指令進行 install/update，並以 `bun run build`、`bun test` 作為升級後基本驗證。
