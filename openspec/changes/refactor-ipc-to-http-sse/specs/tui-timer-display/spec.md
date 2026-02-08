# tui-timer-display Delta Specification

## MODIFIED Requirements

### Requirement: TUI 顯示倒數時間與狀態

OpenTUI SHALL 透過 SSE (Server-Sent Events) 接收 timer 更新，並顯示目前剩餘時間與計時器狀態。

#### Scenario: 透過 SSE 接收 timer 更新並更新畫面

- **WHEN** TUI 從 `EventSource("http://localhost:8080/events")` 接收到 `{"type":"update_timer","remaining_seconds":120,"status":"running"}`
- **THEN** 畫面顯示剩餘秒數 120 與狀態 "running"

#### Scenario: TUI 啟動時連接 Server

- **WHEN** TUI 啟動且 Server 正在運行
- **THEN** TUI 建立 SSE connection 並立即接收當前 timer state

#### Scenario: Server 未運行

- **WHEN** TUI 啟動但無法連接到 `http://localhost:8080`
- **THEN** TUI 顯示錯誤訊息 "Cannot connect to timer server. Please run: bun run server" 並退出

#### Scenario: SSE 連接斷線後重連

- **WHEN** SSE connection 因網路問題斷線
- **THEN** TUI 自動重新連接（`EventSource` 內建重連機制），重連成功後繼續接收 updates
