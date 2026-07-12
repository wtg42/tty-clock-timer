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
系統 MUST 將 Core 產生的 timer 狀態事件回傳到 Node，供 Store/EventBus 更新 UI 投影狀態。`update_timer` 事件 MUST 包含 ETA 欄位，供 TUI 直接顯示，避免前端自行推算。`eta_hhmm` MUST 僅在新的倒數週期起點重算（`start`、`resume`、`reset`），且在同一倒數週期內（包含 running 與 paused）MUST 維持凍結值。

#### Scenario: 倒數更新事件回流 UI
- **WHEN** Zig Core 產生 timer 更新事件
- **THEN** Node MUST 透過 Unix Domain Socket 接收事件並更新可供 OpenTUI 渲染的狀態

#### Scenario: 倒數更新事件包含 ETA
- **WHEN** Zig Core 產生 `update_timer` 事件
- **THEN** 事件 payload MUST 包含 `eta_hhmm` 字串欄位，格式 MUST 為 `HH:MM`（24-hour、到分、不含秒）

#### Scenario: 暫停時 ETA 凍結
- **WHEN** timer 狀態為 paused
- **THEN** 後續 `update_timer` 事件中的 `eta_hhmm` MUST 維持凍結值，直到 timer 進入新的倒數週期

#### Scenario: 執行中 ETA 不重算
- **WHEN** timer 狀態為 running 且尚未發生新的狀態轉換事件（`start`、`resume`、`reset`）
- **THEN** 後續 `update_timer` 事件中的 `eta_hhmm` MUST 持續回傳同一個凍結值，不得因每次 tick 重新推算而改變

#### Scenario: 開始或重跑後 ETA 重算
- **WHEN** timer 進入新的倒數週期（例如初始開始、resume、或 reset 後重跑）
- **THEN** Core MUST 重新計算並回傳新的 `eta_hhmm`

#### Scenario: 分鐘邊界不漂移
- **WHEN** timer 更新發生在 minute boundary 附近（例如剩餘時間與目前時刻的秒級截斷邊界）
- **THEN** `eta_hhmm` MUST 代表同一倒數週期的凍結結束時刻，不得提早跳分鐘或反覆漂移

### Requirement: Socket 生命週期需可恢復
系統 MUST 在 socket 初始化與重啟流程中處理殘留 socket 檔案與連線失敗，並提供可診斷錯誤訊息。系統在每次啟動時 MUST 產生執行實例唯一的 socket path（例如包含 PID、隨機後綴或等效唯一機制），以避免多實例衝突並適用 Linux AppImage 與 macOS 執行環境。系統 MUST 優先嘗試非空且可用的 `TMPDIR`，再 fallback 至 `/tmp`；完整 path MUST 符合平台 Unix Domain Socket 長度限制，且候選過長或不可用時 MUST 嘗試下一候選，而非直接使用無效 path。

#### Scenario: 啟動時存在殘留 socket 檔案
- **WHEN** 進程啟動時發現目標 socket path 已存在且無有效連線
- **THEN** 系統 MUST 執行安全清理或明確報錯，避免無聲失敗

#### Scenario: 同時啟動多個 packaged 實例
- **WHEN** 同一使用者同時啟動兩個以上 Linux AppImage 或 macOS package 實例
- **THEN** 每個實例 MUST 使用不同 socket path，且彼此不應因 path 衝突而導致 IPC 初始化失敗

#### Scenario: macOS TMPDIR 可用且路徑合法
- **WHEN** `TMPDIR` 非空、可使用，且組合後的 socket path 符合平台長度限制
- **THEN** core MUST 在該目錄建立唯一 socket 並於結束時清理

#### Scenario: TMPDIR socket path 過長
- **WHEN** `TMPDIR` 與唯一檔名組合後超出 Unix Domain Socket path 長度限制
- **THEN** core MUST 改以 `/tmp` 產生合法的唯一 socket path
- **AND** core MUST NOT 因第一候選過長而直接終止

