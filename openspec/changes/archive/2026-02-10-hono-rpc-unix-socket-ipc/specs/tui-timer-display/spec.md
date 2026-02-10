## MODIFIED Requirements

### Requirement: TUI 顯示倒數時間與狀態
OpenTUI MUST 顯示目前剩餘時間與計時器狀態，且顯示資料 MUST 來自 Node Store/EventBus 的投影狀態；該投影狀態 MUST 由 Zig Core 回傳事件驅動更新。

#### Scenario: 接收 Core 事件後更新畫面
- **WHEN** Node 收到來自 Zig Core 的 timer 更新事件並同步至 Store
- **THEN** OpenTUI 畫面 MUST 顯示最新剩餘秒數與對應狀態

#### Scenario: 命令觸發後狀態反映至畫面
- **WHEN** 使用者在 UI 發送 pause、resume 或 reset 命令且 Core 完成處理
- **THEN** OpenTUI MUST 透過更新後的 Store 投影狀態反映正確 timer 狀態
