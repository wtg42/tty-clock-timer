## 1. 專案結構準備

- [x] 1.1 建立 `server/` 目錄結構（index.ts, routes.ts, sse.ts, timer-manager.ts）
- [x] 1.2 建立 `tui-client/` 目錄（暫時與舊 `tui/` 並存）
- [x] 1.3 更新 `package.json` 增加 server 和 tui-client 的 scripts

## 2. Bun HTTP Server 核心功能

- [x] 2.1 實作基礎 HTTP server（`Bun.serve()`，監聽指定 port）
- [x] 2.2 實作 port 衝突檢測與環境變數 `PORT` 支援
- [x] 2.3 實作 CORS headers 處理
- [x] 2.4 實作 404 和錯誤處理中介層

## 3. Timer Process Management

- [x] 3.1 實作 `Bun.spawn()` 啟動 Core process（定位 `zig-out/bin/timer-core`）
- [x] 3.2 實作從不同工作目錄正確定位 Core binary 的路徑解析
- [x] 3.3 實作 Core stdout 讀取與 JSON 解析（處理 `update_timer`, `timer_finished`）
- [x] 3.4 實作 Core stdin 寫入（發送命令 JSON）
- [x] 3.5 實作 Core process crash 偵測與錯誤處理
- [x] 3.6 實作 graceful shutdown（SIGINT/SIGTERM 處理，5 秒 timeout）

## 4. SSE (Server-Sent Events) 實作

- [x] 4.1 實作 `GET /events` endpoint（回應 `Content-Type: text/event-stream`）
- [x] 4.2 實作 SSE client connection 管理（維護 active connections Set）
- [x] 4.3 實作事件廣播機制（timer update → 所有 clients）
- [x] 4.4 實作 client 斷線偵測與清理
- [x] 4.5 實作新 client 連接時立即推送當前 state
- [x] 4.6 實作 keep-alive comments（30 秒無事件時發送）
- [x] 4.7 實作 error 事件推送（Core crash 時）

## 5. REST API Endpoints

- [x] 5.1 實作 `POST /start` endpoint（接受 `duration_seconds`，驗證參數，發送命令給 Core）
- [x] 5.2 實作 `POST /pause` endpoint（檢查 timer 狀態，發送命令給 Core）
- [x] 5.3 實作 `POST /resume` endpoint（檢查 timer 狀態，發送命令給 Core）
- [x] 5.4 實作 `POST /reset` endpoint（發送 reset 命令給 Core）
- [x] 5.5 實作 `POST /stop` endpoint（觸發 graceful shutdown）
- [x] 5.6 實作 `GET /status` endpoint（回傳當前 timer state JSON）
- [x] 5.7 實作 API 錯誤處理（400/404/409/503 錯誤回應）

## 6. Server State Management

- [x] 6.1 實作全域 timer state（remaining, status, total_duration, elapsed）
- [x] 6.2 實作 state 更新邏輯（從 Core updates 同步）
- [x] 6.3 實作 state validation（避免無效狀態轉換，例如 pause idle timer）

## 7. TUI Client 重寫

- [x] 7.1 實作 EventSource 連接到 `http://localhost:8080/events`
- [x] 7.2 實作 SSE message 解析與 Solid signals 更新
- [x] 7.3 實作 Server 連線錯誤處理（顯示錯誤訊息並退出）
- [x] 7.4 實作 TTY raw mode input 處理（分離 JSON parsing）
- [x] 7.5 實作鍵盤命令對應的 HTTP POST 請求（space → `/pause`, q → `/stop`）
- [x] 7.6 實作 SSE 重連處理（利用 EventSource 內建機制）
- [x] 7.7 保留 OpenTUI rendering 邏輯（使用新的 signals）

## 8. Zig Core 調整（最小改動）

- [x] 8.1 驗證現有 stdio JSON IPC 協議與 Server 需求一致
- [x] 8.2 若需要，調整 JSON 格式以符合 Server 預期
- [x] 8.3 確保 Core 能正常處理 Server 發送的命令 JSON

## 9. 整合測試

- [x] 9.1 測試 Server 啟動與 Core process spawn
- [x] 9.2 測試單一 TUI client 連接與基本操作（start, pause, resume, reset）
- [x] 9.3 測試多個 TUI clients 同時連接（event broadcast）
- [x] 9.4 測試 Server graceful shutdown（Ctrl+C）
- [x] 9.5 測試錯誤場景（port 衝突、Core binary 不存在、Core crash）
- [x] 9.6 測試 SSE 重連機制
- [x] 9.7 使用 `curl` 測試 REST API endpoints

## 10. 文件更新

- [x] 10.1 更新 `CLAUDE.md`（新架構說明、啟動命令、專案結構）
- [x] 10.2 更新 `README.md`（使用者文件，啟動流程）
- [x] 10.3 更新 `package.json` scripts（`server`, `tui`）
- [x] 10.4 新增 `server/README.md`（API 文件、架構說明）

## 11. 清理與切換

- [x] 11.1 重命名 `tui/` → `tui-legacy/`（保留舊實作）
- [x] 11.2 重命名 `tui-client/` → `tui/`（新實作）
- [x] 11.3 驗證新架構穩定後移除 `tui-legacy/`
- [ ] 11.4 Git tag 標記重構完成版本

## 12. 驗證與優化（可選）

- [x] 12.1 驗證 EventSource 在 Bun runtime 的支援（若不支援則引入 polyfill）
- [x] 12.2 驗證 SSE latency 是否符合預期（< 5ms）
- [x] 12.3 測試 Connection limit（100+ clients 壓力測試）
- [x] 12.4 優化 Server logging（結構化 log，區分 info/error）
