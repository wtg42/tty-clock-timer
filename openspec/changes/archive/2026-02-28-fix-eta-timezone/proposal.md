## Why

ETA 顯示功能目前在 Core（Zig）端將 epoch seconds 格式化為 `HH:MM` 字串，使用的是 UTC 時間，導致非 UTC 時區的使用者看到的 ETA 與本地時鐘不符。修正方式是改由 TUI 端負責格式化，直接利用 JavaScript `Date` 物件取得正確的本地時間。

## What Changes

- **BREAKING** Core IPC `update_timer` 訊息：移除 `eta_hhmm`（`string`）欄位，改為 `eta_epoch_seconds`（`number`，Unix timestamp 秒數）
- Core `formatEtaHhmm` 函式及相關邏輯移除
- TUI 端新增本地時間格式化，將 `eta_epoch_seconds` 轉為本地 `HH:MM` 顯示

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `core-tui-artifact-contract`：`update_timer` 訊息的 ETA 欄位由 `eta_hhmm: string` 改為 `eta_epoch_seconds: number`

## Impact

- `core/src/main.zig`：移除 `formatEtaHhmm`，改傳 raw epoch seconds
- `core/src/lib/ipc.zig`：更新 `UpdateTimerPayload` 結構與序列化/反序列化邏輯
- `tui/src/protocol.ts`：更新型別定義
- `tui/src/store.ts`：新增本地時間格式化邏輯
- `tui/src/index.tsx`：ETA 顯示改用本地時間
- 相關測試需同步更新
