## Why

目前 OpenTUI 畫面無法顯示倒數時間，使用者只能從 CLI 或外部訊息判斷狀態。讓 timer 狀態顯示在 UI 能提升可視性與互動一致性。

## What Changes

- 在 TUI 畫面中顯示倒數時間與狀態
- 透過既有 IPC 訊息更新 UI
- 不改變計時器核心邏輯

## Capabilities

### New Capabilities
- `tui-timer-display`: 在 OpenTUI 顯示 timer 狀態與剩餘時間

### Modified Capabilities

## Impact

- `core/src/lib/ipc.zig`: 確保 timer 更新訊息可供 TUI 使用
- `tui/src/index.tsx`: 顯示 timer 與狀態
