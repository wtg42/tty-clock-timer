# unix-socket-ipc-bridge Specification

## Purpose
TBD - created by syncing change hono-rpc-unix-socket-ipc. Update Purpose after sync.

## Requirements

### Requirement: Core 與 Node 以 Unix Domain Socket 雙向通訊
系統 MUST 使用 Unix Domain Socket 作為 Zig Core 與 Node 之間的雙向 IPC 通道，以承載 command 與 event 訊息。

#### Scenario: Node 將 command 送至 Core
- **WHEN** Node adapter 收到來自 Hono command plane 的命令
- **THEN** 命令 MUST 經由 Unix Domain Socket 傳送至 Zig Core 並得到對應處理結果

### Requirement: Core 事件可回流 Node 投影層
系統 MUST 將 Core 產生的 timer 狀態事件回傳到 Node，供 Store/EventBus 更新 UI 投影狀態。

#### Scenario: 倒數更新事件回流 UI
- **WHEN** Zig Core 產生 timer 更新事件
- **THEN** Node MUST 透過 Unix Domain Socket 接收事件並更新可供 OpenTUI 渲染的狀態

### Requirement: Socket 生命週期需可恢復
系統 MUST 在 socket 初始化與重啟流程中處理殘留 socket 檔案與連線失敗，並提供可診斷錯誤訊息。系統在每次啟動時 MUST 產生執行實例唯一的 socket path（例如包含 PID、隨機後綴或等效唯一機制），以避免多實例衝突並適用 AppImage 執行環境。

#### Scenario: 啟動時存在殘留 socket 檔案
- **WHEN** 進程啟動時發現目標 socket path 已存在且無有效連線
- **THEN** 系統 MUST 執行安全清理或明確報錯，避免無聲失敗

#### Scenario: 同時啟動多個 AppImage 實例
- **WHEN** 同一使用者同時啟動兩個以上程式實例
- **THEN** 每個實例 MUST 使用不同 socket path，且彼此不應因 path 衝突而導致 IPC 初始化失敗
