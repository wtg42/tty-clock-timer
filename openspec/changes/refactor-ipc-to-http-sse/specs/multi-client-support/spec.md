# multi-client-support Specification

## Purpose

支援多個 clients（TUI, IDE plugin, CLI 等）同時連接 Server，共享並觀察同一個 timer instance。

## ADDED Requirements

### Requirement: 允許多個 SSE Clients 同時連接

Server SHALL 支援多個 clients 同時連接 `/events` endpoint，所有 clients 接收相同的 timer 事件。

#### Scenario: 多個 Clients 同時連接

- **WHEN** Client A 和 Client B 同時連接 `GET /events`
- **THEN** Server 建立兩個獨立的 SSE connections，並在 timer update 時向兩者推送相同事件

#### Scenario: Client 後續加入

- **WHEN** Client A 已連接，timer 正在運行，然後 Client B 連接
- **THEN** Server 向 Client B 立即推送當前 timer state，之後所有 clients 接收相同的 updates

### Requirement: Shared Timer State

所有 clients SHALL 觀察並控制同一個 timer instance，任何 client 的命令會影響所有 clients 看到的狀態。

#### Scenario: Client A 啟動 Timer，Client B 觀察

- **WHEN** Client A 發送 `POST /start` 並附帶 `{"duration_seconds":300}`
- **THEN** Server 啟動 timer，Client A 和 Client B 都收到 `{"type":"update_timer","status":"running",...}` 事件

#### Scenario: Client B 暫停 Timer，Client A 觀察

- **WHEN** Client B 發送 `POST /pause` 且 timer 在運行中
- **THEN** Server 暫停 timer，Client A 和 Client B 都收到 `{"type":"update_timer","status":"paused",...}` 事件

### Requirement: 無 Client Session 隔離

Server SHALL 不區分不同 clients 的 session，所有 API 操作共享全域 timer 狀態。

#### Scenario: 無需認證或 Session ID

- **WHEN** 任何 client 發送 `POST /pause` 請求
- **THEN** Server 執行命令，不檢查 session ID 或 authentication token

### Requirement: Connection Limit（可選）

Server MAY 限制同時連接的 SSE clients 數量以避免資源耗盡。

#### Scenario: 超過連接數上限

- **WHEN** 已有 100 個 clients 連接且 Client 101 嘗試連接 `/events`
- **THEN** Server 回應 HTTP 503 Service Unavailable 和 `{"error":"Too many connections"}`

#### Scenario: 正常連接數

- **WHEN** 有 5 個 clients 連接且 Client 6 嘗試連接
- **THEN** Server 正常建立 SSE connection（假設上限 >= 6）
