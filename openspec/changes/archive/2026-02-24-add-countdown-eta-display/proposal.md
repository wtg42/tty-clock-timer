## Why

目前 TUI 只顯示剩餘倒數時間，使用者無法直接看到「幾點會結束」。
在倒數主畫面新增 ETA（到分）可降低心智換算負擔，提升可預期性。

## What Changes

- 在倒數主畫面新增 ETA 顯示，格式固定為 `ETA HH:MM`（不顯示秒、不使用 Emoji）。
- 由 Zig Core 提供 ETA 相關欄位到 IPC 事件，TUI 僅消費與顯示，不在 UI 端自行推算。
- 定義 ETA 行為：paused 時刻凍結；當 timer 開始或重跑時重新計算 ETA。
- 確保新增 ETA 後，既有 ASCII 倒數主顯示、狀態列與控制鍵提示仍維持可讀且不互相覆蓋。

## Capabilities

### New Capabilities

- 無

### Modified Capabilities

- `tui-timer-display`: 擴充倒數畫面需求，加入 ETA 顯示內容與不同 timer 狀態下的顯示規則。
- `unix-socket-ipc-bridge`: 擴充 `update_timer` 事件 payload，加入 ETA 欄位供 TUI 直接顯示。

## Impact

- 影響 `core/src/lib/ipc.zig` 與 Core 事件送出流程（新增 ETA 欄位）。
- 影響 `tui/src/protocol.ts`、`tui/src/store.ts`、`tui/src/index.tsx` 的型別、投影與顯示。
- 不調整現有控制鍵語義與倒數主字體顯示。
