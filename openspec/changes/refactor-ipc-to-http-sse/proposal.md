## Why

現有架構使用 stdio pipes 進行 Core (Zig) 與 TUI 之間的 IPC 通訊，導致 stdin 同時承載 JSON 訊息與 TTY raw mode 輸入，造成關注點混雜。重構為 HTTP + SSE 架構可實現清晰的職責分離，並支援多種 client 類型（TUI、IDE plugin、headless client），類似 OpenCode 的可擴展架構。

## What Changes

- **新增** Bun HTTP Server 作為中心化的狀態管理與事件廣播層
- **新增** SSE (Server-Sent Events) endpoint 用於即時推送 timer 事件給多個 clients
- **新增** REST API endpoints 用於 timer 控制命令（start, pause, reset, stop）
- **修改** Core (Zig) 從 child process 模式改為獨立 CLI，透過 stdio 與 Server 通訊
- **修改** TUI 從直接 spawn core process 改為 HTTP client，透過 EventSource 接收更新
- **移除** TUI 與 Core 之間的直接 parent-child process 關係
- **移除** stdin 的雙重用途（IPC + TTY input）

## Capabilities

### New Capabilities

- `http-server`: Bun HTTP server 提供 REST API 和 SSE endpoints，管理 timer 狀態與多 client 廣播
- `sse-events`: Server-Sent Events 機制，即時推送 timer 更新給所有連接的 clients
- `rest-api`: RESTful API endpoints 處理 timer 控制命令（POST /start, /pause, /reset, /stop, GET /status）
- `multi-client-support`: 支援多個 clients 同時連接並觀察同一個 timer 實例

### Modified Capabilities

- `cli-launch-ui`: Core CLI 不再直接 spawn UI process；改為 Server spawn Core，TUI 作為獨立 HTTP client
- `tui-timer-display`: TUI 改用 EventSource 接收 SSE 事件，使用 fetch API 發送控制命令
- `quit-on-q`: 'q' 鍵不再直接觸發 process exit，改為發送 HTTP POST /stop 請求

## Impact

**受影響的程式碼：**
- `core/src/main.zig`: IPC 通訊方式不變（仍使用 stdio），但 lifecycle 由 Server 管理
- `tui/src/index.tsx`: 完全重寫 client 邏輯，改用 HTTP/SSE
- 新增 `server/` 目錄：包含 Bun HTTP server、路由、SSE 處理、timer process 管理

**API 變更：**
- **BREAKING**: TUI 啟動方式從 `bun tui/src/index.tsx` 改為先啟動 server，再啟動 TUI client
- **BREAKING**: Core 不再作為 main process，改為由 Server spawn 的 child process

**依賴：**
- 新增 Bun HTTP server 依賴（Bun 內建，無需額外安裝）
- TUI 需要 `EventSource` 支援（需確認 Bun runtime 支援）

**系統架構：**
- Process model 從單一 parent-child 改為 Server (parent) → Core (child) + TUI (client)
- 通訊協議從 stdio pipes 改為 HTTP/SSE
