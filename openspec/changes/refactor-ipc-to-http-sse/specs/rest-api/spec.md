# rest-api Specification

## Purpose

提供 RESTful API endpoints 處理 timer 控制命令（start, pause, resume, reset, stop）和狀態查詢。

## ADDED Requirements

### Requirement: POST /start - 啟動 Timer

Server SHALL 提供 `POST /start` endpoint 接受 duration 參數並啟動 timer。

#### Scenario: 成功啟動 Timer

- **WHEN** Client 發送 `POST /start` 並附帶 JSON body `{"duration_seconds":300}`
- **THEN** Server 回應 HTTP 200 和 `{"status":"started","duration":300}`，並透過 Core stdin 發送 start 命令

#### Scenario: 缺少 duration 參數

- **WHEN** Client 發送 `POST /start` 但 body 缺少 `duration_seconds`
- **THEN** Server 回應 HTTP 400 和錯誤訊息 `{"error":"Missing duration_seconds"}`

#### Scenario: Timer 已在運行

- **WHEN** Client 發送 `POST /start` 但 timer 已在 running 狀態
- **THEN** Server 回應 HTTP 409 Conflict 和 `{"error":"Timer already running"}`

### Requirement: POST /pause - 暫停 Timer

Server SHALL 提供 `POST /pause` endpoint 暫停運行中的 timer。

#### Scenario: 成功暫停 Timer

- **WHEN** Client 發送 `POST /pause` 且 timer 在 running 狀態
- **THEN** Server 回應 HTTP 200 和 `{"status":"paused"}`，並透過 Core stdin 發送 pause 命令

#### Scenario: Timer 未在運行

- **WHEN** Client 發送 `POST /pause` 但 timer 狀態為 idle 或 finished
- **THEN** Server 回應 HTTP 400 和 `{"error":"Timer not running"}`

### Requirement: POST /resume - 恢復 Timer

Server SHALL 提供 `POST /resume` endpoint 恢復暫停的 timer。

#### Scenario: 成功恢復 Timer

- **WHEN** Client 發送 `POST /resume` 且 timer 在 paused 狀態
- **THEN** Server 回應 HTTP 200 和 `{"status":"running"}`，並透過 Core stdin 發送 resume 命令

#### Scenario: Timer 未暫停

- **WHEN** Client 發送 `POST /resume` 但 timer 狀態不是 paused
- **THEN** Server 回應 HTTP 400 和 `{"error":"Timer not paused"}`

### Requirement: POST /reset - 重置 Timer

Server SHALL 提供 `POST /reset` endpoint 重置 timer 到初始狀態。

#### Scenario: 成功重置 Timer

- **WHEN** Client 發送 `POST /reset`
- **THEN** Server 回應 HTTP 200 和 `{"status":"idle"}`，並透過 Core stdin 發送 reset 命令

### Requirement: POST /stop - 停止 Server

Server SHALL 提供 `POST /stop` endpoint 觸發 graceful shutdown。

#### Scenario: 成功停止 Server

- **WHEN** Client 發送 `POST /stop`
- **THEN** Server 回應 HTTP 200 和 `{"status":"stopping"}`，然後執行 graceful shutdown 流程

### Requirement: GET /status - 查詢 Timer 狀態

Server SHALL 提供 `GET /status` endpoint 回傳當前 timer 狀態。

#### Scenario: 查詢運行中的 Timer

- **WHEN** Client 發送 `GET /status` 且 timer 在 running 狀態
- **THEN** Server 回應 HTTP 200 和 JSON：
  ```json
  {
    "status": "running",
    "remaining_seconds": 120,
    "total_duration": 300,
    "elapsed_seconds": 180
  }
  ```

#### Scenario: 查詢 Idle Timer

- **WHEN** Client 發送 `GET /status` 且 timer 在 idle 狀態
- **THEN** Server 回應 HTTP 200 和 `{"status":"idle"}`

### Requirement: CORS Headers

Server SHALL 在所有 API 回應中包含 CORS headers 以支援瀏覽器 clients。

#### Scenario: Preflight Request

- **WHEN** Client 發送 `OPTIONS /start` preflight request
- **THEN** Server 回應 HTTP 204 並附帶 headers：
  ```
  Access-Control-Allow-Origin: *
  Access-Control-Allow-Methods: GET, POST, OPTIONS
  Access-Control-Allow-Headers: Content-Type
  ```

### Requirement: Error Handling

Server SHALL 統一回傳錯誤格式為 `{"error":"message"}`。

#### Scenario: 無效的 JSON Body

- **WHEN** Client 發送 `POST /start` 但 body 不是有效的 JSON
- **THEN** Server 回應 HTTP 400 和 `{"error":"Invalid JSON"}`

#### Scenario: 不存在的 Endpoint

- **WHEN** Client 發送請求到不存在的 endpoint（例如 `GET /unknown`）
- **THEN** Server 回應 HTTP 404 和 `{"error":"Not found"}`
