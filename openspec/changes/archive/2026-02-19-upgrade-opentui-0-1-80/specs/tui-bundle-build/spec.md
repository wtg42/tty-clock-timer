## ADDED Requirements

### Requirement: Build 流程 MUST 與 OpenTUI v0.1.80 相容
升級至 OpenTUI v0.1.80 後，bun build 流程（使用 `@opentui/solid/bun-plugin` 和 external native binding 設定）MUST 能正確編譯並產出可執行的 bundle，包括 platform-specific 原生包的正確複製。

#### Scenario: Build 在升級後成功執行
- **WHEN** 執行 `bun run build`（使用 OpenTUI v0.1.80）
- **THEN** Bundle 成功產出至 `tui/dist/`，不含 TypeScript 或編譯錯誤

#### Scenario: Solid plugin API 相容性
- **WHEN** 檢視 build output
- **THEN** JSX 轉換正確執行，bundle 中不含未轉換的 TSX 語法

#### Scenario: 原生包結構維持一致
- **WHEN** 執行 build 並檢視 dist 目錄結構
- **THEN** `libopentui.so` 被正確複製至 `tui/dist/`，shim 檔案正確產出

### Requirement: Bundle 產物 MUST 在新版本中正常執行
v0.1.80 的 bug fix（Grapheme 處理、input 緩衝、ScrollBox）MUST 不破壞現有的 TUI 功能，bundle 執行後 MUST 正常渲染倒計時顯示。

#### Scenario: 基本 TUI 功能測試
- **WHEN** AppImage 啟動（使用升級後的 bundle）
- **THEN** TUI 正常渲染，計時器時間正確更新，鍵盤輸入（p/r/s/q）正常回應
