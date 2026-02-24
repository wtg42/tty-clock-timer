## MODIFIED Requirements

### Requirement: Core 事件可回流 Node 投影層
系統 MUST 將 Core 產生的 timer 狀態事件回傳到 Node，供 Store/EventBus 更新 UI 投影狀態。`update_timer` 事件 MUST 包含 ETA 欄位，供 TUI 直接顯示，避免前端自行推算。

#### Scenario: 倒數更新事件包含 ETA
- **WHEN** Zig Core 產生 `update_timer` 事件
- **THEN** 事件 payload MUST 包含 `eta_hhmm` 字串欄位，格式 MUST 為 `HH:MM`（24-hour、到分、不含秒）

#### Scenario: 暫停時 ETA 凍結
- **WHEN** timer 狀態為 paused
- **THEN** 後續 `update_timer` 事件中的 `eta_hhmm` MUST 維持凍結值，直到 timer 進入新的倒數週期

#### Scenario: 開始或重跑後 ETA 重算
- **WHEN** timer 開始新的倒數週期（例如初始開始、resume、或 reset 後重跑）
- **THEN** Core MUST 重新計算並回傳新的 `eta_hhmm`
