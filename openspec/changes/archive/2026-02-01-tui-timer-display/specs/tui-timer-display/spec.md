## ADDED Requirements

### Requirement: TUI 顯示倒數時間與狀態
OpenTUI MUST 顯示目前剩餘時間與計時器狀態，且資訊需來自 IPC timer 更新訊息。

#### Scenario: 接收 timer 更新並更新畫面
- **WHEN** UI 收到 IPC 的 timer 更新訊息
- **THEN** 畫面顯示剩餘秒數與對應狀態
