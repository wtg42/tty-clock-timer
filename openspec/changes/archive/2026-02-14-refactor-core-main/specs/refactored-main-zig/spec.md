# 重構後的 main.zig 規格

## ADDED Requirements

### Requirement: main() 函數清晰的執行流程
重構後的 `main()` 函數應清晰呈現應用程序的核心流程，主流程部分應控制在 ~40 行以內，讓新開發者可快速理解整體架構。

#### Scenario: 開發者可快速掃描主流程
- **WHEN** 開發者打開 `core/src/main.zig` 的 `main()` 函數
- **THEN** 可在主函數前 50 行內看到完整的邏輯流程骨架（stdin 設定 → CLI 解析 → timer 啟動 → socket 設定 → TUI 生成 → 事件循環）

#### Scenario: 每個初始化步驟都對應一個獨立函數
- **WHEN** main() 調用 `setupRawMode()` 或 `setupSocket()` 等函數
- **THEN** 每個函數專責一項初始化任務，職責邊界清晰

### Requirement: 提取的函數應有明確職責
新提取的函數（`setupRawMode()`、`setupSocket()`、`findUiCwd()`、`runEventLoop()`）應各自承擔明確的單一職責，易於單獨理解和測試。

#### Scenario: setupRawMode() 管理終端設定
- **WHEN** 應用程序啟動
- **THEN** `setupRawMode()` 函數負責 termios 配置、保存原始設定、並通過 defer 恢復

#### Scenario: runEventLoop() 包含完整的事件循環邏輯
- **WHEN** socket 連線建立後
- **THEN** `runEventLoop()` 函數包含所有 poll、stdin/socket buffer 處理、timer 更新、訊息發送邏輯

### Requirement: 消除不必要的記憶體配置
應消除 `updateTimer()` 中對 comptime 字面量的不必要 heap 複製操作，降低每秒執行時的記憶體壓力。

#### Scenario: updateTimer() 不再複製 status 字串
- **WHEN** `updateTimer()` 發送計時器更新訊息
- **THEN** status 字串直接使用 `timerStateToStatus()` 回傳的 comptime 字面量，不執行 `allocator.dupe()`

### Requirement: 移除未使用的代碼
應移除 `Config` 中未初始化、未使用的 `reset_mode` 欄位，減少代碼噪音和維護負擔。

#### Scenario: Config.reset_mode 欄位被移除
- **WHEN** 執行 `zig build test`
- **THEN** 所有編譯和測試通過，且 `config.zig` 中不存在 `reset_mode` 欄位

### Requirement: Socket poll 邏輯清晰易懂
Socket 輪詢中的 stdin/socket 索引計算應使用具名常數或結構化配置，提高代碼可讀性。

#### Scenario: poll 邏輯使用具名索引
- **WHEN** 事件循環執行 `std.posix.poll()`
- **THEN** stdin 和 socket 的 fd index 使用具名常數（如 `STDIN_FD_INDEX`、`SOCKET_FD_INDEX`）或結構化配置，而非隱含計算

## PRESERVED Requirements

所有原有的計時器行為、IPC 訊息格式、CLI 參數解析、socket 通信都應保持不變。重構僅涉及內部實作整理，對外部使用者和整體功能無影響。

#### Scenario: 計時器倒數正常進行
- **WHEN** 執行 `zig build run -- --minutes 1`
- **THEN** 計時器正常倒數，行為與重構前相同

#### Scenario: IPC 訊息格式保持一致
- **WHEN** core 和 TUI 通過 unix socket 通信
- **THEN** 所有訊息格式（`update_timer`, `timer_finished`, `exit`, `command`, `command_result`）保持不變
