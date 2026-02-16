## Why

目前 `tui/` 缺少可重複執行的 function-level unit tests，導致純函式邏輯（例如資料轉換、格式化、狀態計算）在重構時容易引入回歸。現在補齊單元測試可在不依賴整體 feature 流程下，快速驗證核心函式正確性並降低維護風險。

## What Changes

- 在 `tui/` 建立可執行的 unit test 基礎設施與執行指令。
- 新增或調整可測試的純函式邊界，讓邏輯可被獨立測試。
- 為主要 function-level 邏輯補上測試案例，覆蓋正常路徑與錯誤/邊界路徑。
- 明確排除 feature tests（跨模組流程、UI 整體互動、端到端行為）於此次範圍外。

## Capabilities

### New Capabilities
- `tui-function-unit-tests`: 為 TUI 提供僅針對函式層級邏輯的單元測試能力與一致執行方式。

### Modified Capabilities
- （無）

## Impact

- Affected code: `tui/src/**` 中可抽離為純函式的邏輯模組，以及新增 `tui` 測試檔案。
- Tooling: `tui` 端新增測試相關依賴與 scripts（以現有工具鏈為準）。
- CI/Local workflow: 開發者可在本機執行 function-level 測試以快速回饋。
