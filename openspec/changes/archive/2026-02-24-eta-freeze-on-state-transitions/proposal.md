## Why

目前 ETA 在 running 期間會隨每次投影更新反覆重算，靠近 minute boundary 時容易因秒級截斷造成顯示提早跳分鐘（漂移）。這會讓使用者看到不穩定或不可信的 ETA，因此需要把 ETA 語義收斂為事件驅動重算與週期內凍結。

## What Changes

- 將 ETA 重算時機限定為狀態轉換事件：`start`、`resume`、`reset`。
- timer 處於 running 期間，`update_timer` 僅回傳 frozen ETA，不在每個 tick 重新推算。
- 保留 paused 的 ETA 凍結語義，暫停期間 ETA 不變。
- 新增 minute boundary 測試案例，驗證邊界時間不會發生 ETA 漂移。

## Capabilities

### New Capabilities
- （無）

### Modified Capabilities
- `unix-socket-ipc-bridge`: 調整 `update_timer.eta_hhmm` 的生成語義，明確要求 ETA 僅於 `start/resume/reset` 重算，running 與 paused 期間維持凍結值，並補強 minute boundary 無漂移要求。

## Impact

- 受影響程式：`core/src/main.zig` 的 ETA projection 邏輯與相關測試。
- 受影響契約：`update_timer` 事件中的 `eta_hhmm` 行為語義（欄位與格式不變）。
- TUI 顯示與 IPC message schema 維持相容，不需新增欄位。
