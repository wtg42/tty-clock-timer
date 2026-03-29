## MODIFIED Requirements

### Requirement: TUI MUST 可透過 bun build 產出單一 JS bundle
系統 MUST 提供 build script（`tui/build.ts`），使用 `Bun.build()` 搭配 `@opentui/solid/bun-plugin` 將 `src/index.tsx` 及其所有 JS/TS 依賴打包為單一 bundle 檔案，輸出至 `tui/dist/`。依賴版本 MUST 以同一批次的 `@opentui/core` 與 `@opentui/solid` 為準，且 `solid-js` MUST 對齊該批次 `@opentui/solid` 的 peer expectation，以降低未來 API 漂移與 peer mismatch 風險。

#### Scenario: 執行 build 產出 bundle
- **WHEN** 開發者在 `tui/` 目錄執行 `bun run build`
- **THEN** 系統 MUST 在 `tui/dist/` 產出可由 `bun` 直接執行的 JS bundle 檔案
