## Why

目前 CLI 在未提供參數時會回傳錯誤並結束，雖然有簡短 usage，但整體輸出在 `zig build run --` 情境下容易被視為「程式壞掉」。
需要讓「沒有參數」時的互動更友善，降低新使用者的理解成本並提升首次使用體驗。

## What Changes

- 調整 CLI 在未提供任何參數時的預設行為：顯示完整 help 說明（與 `--help` 一致）而非僅輸出錯誤訊息。
- 明確定義「無參數」情境的退出語意（採友善模式：視同 help 顯示）。
- 補齊對應規格與測試案例，覆蓋 help 內容與無參數行為。

## Capabilities

### New Capabilities
- `cli-help-default-behavior`: 定義 CLI 在無參數啟動時的預設說明輸出與退出語意。

### Modified Capabilities
- （無）

## Impact

- Affected spec: `openspec/specs/cli-help-default-behavior/spec.md`（新建）。
- Affected code: `core/src/lib/config.zig`、`core/src/main.zig`。
- Affected tests: `core/src/lib/config.zig` 與 `core/src/main.zig` 相關 parse/error message 測試。
