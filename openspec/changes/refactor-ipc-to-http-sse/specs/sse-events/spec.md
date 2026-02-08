# sse-events Specification

## Purpose

實作 Server-Sent Events (SSE) 機制，讓 Server 能即時推送 timer 狀態更新給多個連接的 clients。

## ADDED Requirements

### Requirement: 提供 SSE Endpoint

Server SHALL 在 `GET /events` 提供 SSE endpoint，回應 `Content-Type: text/event-stream`。

#### Scenario: Client 連接 SSE Endpoint

- **WHEN** Client 發送 `GET /events` 請求並附帶 `Accept: text/event-stream` header
- **THEN** Server 建立 SSE connection，回應 HTTP 200 和 `Content-Type: text/event-stream` header

#### Scenario: 非 SSE 請求

- **WHEN** Client 發送 `GET /events` 但未附帶 `Accept: text/event-stream` header
- **THEN** Server 回應 HTTP 406 Not Acceptable

### Requirement: 推送 Timer Update 事件

Server SHALL 在收到 Core 的 timer update 訊息時，透過 SSE 推送給所有連接的 clients。

#### Scenario: 廣播 Timer Update

- **WHEN** Core 發送 `{"type":"update_timer","remaining_seconds":120,"status":"running",...}`
- **THEN** Server 向所有 SSE clients 發送：
  ```
  data: {"type":"update_timer","remaining_seconds":120,"status":"running",...}

  ```

#### Scenario: 多個 Clients 同時連接

- **WHEN** 有 3 個 clients 連接到 `/events` 且 Core 發送一次 update
- **THEN** 所有 3 個 clients 同時收到相同的 update 事件

### Requirement: 推送 Timer Finished 事件

Server SHALL 在 timer 完成時推送 finished 事件給所有 clients。

#### Scenario: Timer 完成

- **WHEN** Core 發送 `{"type":"timer_finished"}`
- **THEN** Server 向所有 SSE clients 發送：
  ```
  data: {"type":"timer_finished"}

  ```

### Requirement: 推送 Error 事件

Server SHALL 在發生錯誤時（例如 Core crash）推送 error 事件給所有 clients。

#### Scenario: Core Process Crash

- **WHEN** Core process crash 且 exit code 為 1
- **THEN** Server 向所有 SSE clients 發送：
  ```
  data: {"type":"error","message":"Core process crashed with exit code 1"}

  ```

### Requirement: 處理 Client 斷線

Server SHALL 偵測 client 斷線並清理該 connection。

#### Scenario: Client 主動關閉連接

- **WHEN** Client 關閉 SSE EventSource
- **THEN** Server 從 active connections 列表移除該 client

#### Scenario: Client 斷線後重連

- **WHEN** Client 斷線後重新連接 `/events`
- **THEN** Server 建立新的 SSE connection 並立即推送當前 timer state

### Requirement: Keep-Alive

Server SHALL 定期發送 keep-alive comments 以維持 SSE connection 活躍。

#### Scenario: 無事件時發送 Keep-Alive

- **WHEN** 超過 30 秒沒有任何事件推送
- **THEN** Server 發送 `: keep-alive\n\n` comment 給所有 clients
