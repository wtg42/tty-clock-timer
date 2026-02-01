## Why

目前從 `core/` 目錄執行 `zig build run` 時，CLI 會找不到 UI 目錄而無法啟動 UI，導致使用流程中斷。需要讓 CLI 在不同工作目錄下仍能可靠定位 UI 目錄。

## What Changes

- 調整 UI 目錄搜尋規則，能在 `core/` 或專案根目錄啟動時正確找到 `tui/`。
- UI 目錄找不到時提供更清楚的錯誤訊息與搜尋路徑提示。

## Capabilities

### New Capabilities

(無)

### Modified Capabilities

- `cli-launch-ui`: 更新 UI 目錄定位的需求，涵蓋多種啟動工作目錄情境。

## Impact

- `core/src/main.zig` 的 UI 目錄搜尋邏輯與錯誤輸出。
- 開發者在 `core/` 目錄執行 CLI 的體驗。
