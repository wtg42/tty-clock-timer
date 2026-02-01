## Why

目前 UI 需要獨立啟動，使用者必須手動開啟 OpenTUI 才能看到倒數資訊，流程不一致且容易遺漏。讓 CLI 直接啟動 UI 能提升使用體驗並確保顯示與計時同步。

## What Changes

- CLI 啟動計時器時自動啟動 OpenTUI
- UI 與計時器透過既有 IPC 管道連接
- 不改變計時器核心邏輯

## Capabilities

### New Capabilities
- `cli-launch-ui`: CLI 啟動時自動啟動 OpenTUI 並建立 IPC 連線

### Modified Capabilities

## Impact

- `core/src/main.zig`: 啟動流程整合 OpenTUI
- `core/src/lib/ipc.zig`: UI 進程啟動與通訊初始化（如需）
