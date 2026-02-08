# http-server Specification

## Purpose

提供基於 Bun 的 HTTP Server，作為 timer 系統的中心化狀態管理與事件廣播層，負責管理 Zig Core process lifecycle、處理 client 請求、廣播 timer 事件。

## ADDED Requirements

### Requirement: Server 啟動與監聽

Server SHALL 在指定 port 啟動並監聽 HTTP 請求，預設使用 port 8080，可透過環境變數 `PORT` 自訂。

#### Scenario: 成功啟動 Server

- **WHEN** 使用者執行 `bun run server` 且 port 8080 未被佔用
- **THEN** Server 在 port 8080 啟動並輸出 "Server running on :8080"

#### Scenario: Port 已被佔用

- **WHEN** 使用者執行 `bun run server` 但 port 8080 已被其他程序佔用
- **THEN** Server 啟動失敗並輸出錯誤訊息，建議使用環境變數 `PORT` 指定其他 port

#### Scenario: 自訂 Port

- **WHEN** 使用者設定環境變數 `PORT=3000` 並執行 `bun run server`
- **THEN** Server 在 port 3000 啟動

### Requirement: 管理 Zig Core Process

Server SHALL 在啟動後立即 spawn Zig Core process，並透過 stdio pipes 建立雙向通訊。

#### Scenario: 成功啟動 Core Process

- **WHEN** Server 啟動完成
- **THEN** Server 透過 `Bun.spawn()` 啟動 `zig-out/bin/timer-core` 並建立 stdin/stdout pipes

#### Scenario: Core Process 啟動失敗

- **WHEN** Core binary 不存在或無執行權限
- **THEN** Server 輸出錯誤訊息並終止，錯誤訊息包含預期的 binary 路徑

#### Scenario: Core Process Crash

- **WHEN** Core process 在運行中 crash（exit code !== 0）
- **THEN** Server 廣播 `error` 事件給所有 SSE clients，錯誤訊息包含 exit code 和 stderr 輸出

### Requirement: 處理 Core Process 的 stdout 訊息

Server SHALL 持續讀取 Core process 的 stdout，解析 JSON 訊息，並根據訊息類型觸發相應的事件廣播。

#### Scenario: 接收 Timer Update 訊息

- **WHEN** Core process 透過 stdout 發送 `{"type":"update_timer","remaining_seconds":120,...}`
- **THEN** Server 解析訊息並更新內部 timer state，然後透過 SSE 廣播給所有連接的 clients

#### Scenario: 接收 Timer Finished 訊息

- **WHEN** Core process 透過 stdout 發送 `{"type":"timer_finished"}`
- **THEN** Server 更新 timer status 為 "finished" 並廣播給所有 clients

#### Scenario: 接收無效 JSON

- **WHEN** Core process 透過 stdout 發送非 JSON 格式的資料
- **THEN** Server 記錄錯誤到 stderr 但不中斷運行

### Requirement: 傳送命令給 Core Process

Server SHALL 將 HTTP API 接收到的控制命令轉換為 JSON 訊息，透過 stdin 傳送給 Core process。

#### Scenario: 傳送 Start 命令

- **WHEN** Server 接收到 `POST /start` 請求並附帶 `{"duration_seconds":300}`
- **THEN** Server 透過 Core stdin 寫入 `{"cmd":"start","duration":300}\n`

#### Scenario: 傳送 Pause 命令

- **WHEN** Server 接收到 `POST /pause` 請求
- **THEN** Server 透過 Core stdin 寫入 `{"cmd":"pause"}\n`

### Requirement: Graceful Shutdown

Server SHALL 在接收到 SIGINT/SIGTERM 時執行 graceful shutdown，關閉所有 SSE connections 並終止 Core process。

#### Scenario: 正常關閉

- **WHEN** 使用者按下 Ctrl+C (SIGINT)
- **THEN** Server 向所有 SSE clients 發送 close event，等待 Core process 正常終止（最多 5 秒），然後退出

#### Scenario: Core Process 不響應關閉

- **WHEN** Graceful shutdown 時 Core process 在 5 秒內未終止
- **THEN** Server 強制 kill Core process (SIGKILL) 並退出
