## MODIFIED Requirements

### Requirement: Core 與 TUI 的 IPC update_timer 訊息格式
Core 發送 `update_timer` IPC 訊息時，ETA 欄位 MUST 使用 `eta_epoch_seconds`（Unix timestamp，單位：秒，型別：`number`）。`eta_hhmm` 欄位 MUST NOT 出現於訊息中。TUI 端 MUST 將 `eta_epoch_seconds` 轉換為本地時間的 `HH:MM` 格式後顯示給使用者。

#### Scenario: Core 傳送 update_timer 訊息
- **WHEN** 計時器狀態更新並觸發 IPC 通知
- **THEN** Core MUST 在 `update_timer` payload 中包含 `eta_epoch_seconds` 數值欄位，且 MUST NOT 包含 `eta_hhmm` 字串欄位

#### Scenario: TUI 顯示 ETA 本地時間
- **WHEN** TUI 收到含 `eta_epoch_seconds` 的 `update_timer` 訊息
- **THEN** TUI MUST 將其轉換為系統本地時區的 `HH:MM` 格式並顯示，而非 UTC 時間
