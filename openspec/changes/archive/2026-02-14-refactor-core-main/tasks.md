# 實施任務清單

## 1. 準備和驗證

- [x] 1.1 確認當前代碼可編譯和測試通過（基準線）
- [x] 1.2 建立 git branch `refactor-core-main`
- [x] 1.3 複習 design.md，理解提取函數的職責分配

## 2. 提取初始化函數

- [x] 2.1 提取 `setupRawMode()` 函數
  - 將 Step 3 (行 234-263) 的 termios 配置提取為獨立函數
  - 回傳結構體 `RawModeContext` 包含 `original_termios: ?termios`
  - 修改 main() 調用 `setupRawMode()` 並使用 defer 恢復
  - 驗證編譯無誤

- [x] 2.2 提取 `findUiCwd()` 函數
  - 將 Step 6 (行 304-314) 的 TUI 目錄搜尋提取為獨立函數
  - 嘗試 `"tui"`, `"../tui"`, `"../../tui"` 三個候選
  - 回傳 `?[]const u8`
  - 修改 main() 調用此函數
  - 驗證編譯無誤

- [x] 2.3 提取 `setupSocket()` 函數
  - 將 Step 7 (行 316-335) 的 socket 初始化提取為獨立函數
  - 建立 `SocketServerContext` 結構體包含 `server: std.Io.net.Server`
  - 負責 `clearSocketPath()` → `UnixAddress.init()` → `listen()`
  - 回傳 context 和 defer deinit()
  - 修改 main() 調用此函數
  - 驗證編譯無誤

## 3. 提取事件循環

- [x] 3.1 提取 `runEventLoop()` 函數
  - 將 Step 10 主事件循環 (行 399-527) 完整提取為獨立函數
  - 簽名包含：countdown_timer, socket_server, socket_stream, stdin_reader, stdout_writer 等所有必要參數
  - 包含 poll、buffer 填充、stdin/socket 命令處理、timer 更新、訊息發送邏輯
  - 修改 main() 調用此函數
  - 驗證編譯無誤

- [x] 3.2 簡化 main() 主流程
  - 驗證 main() 函數現在約 40-50 行，邏輯清晰
  - 檢查 Step 1-9 的註解保留，使讀者易於理解
  - 驗證編譯和測試通過

## 4. 修正 IPC 層

- [x] 4.1 修正 `updateTimer()` heap dupe
  - 打開 `core/src/lib/ipc.zig`，定位 `updateTimer()` 函數 (行 299-314)
  - 移除 `allocator.dupe(u8, status)` 調用和 `defer allocator.free()`
  - 直接傳遞 `status` 參數到 Message
  - 驗證編譯無誤

- [x] 4.2 驗證 updateTimer() 修改無副作用
  - 使用 grep 確認 updateTimer() 僅在 main.zig 的 `sendTimerProjection()` 內呼叫
  - 確認無其他使用處
  - 驗證編譯和測試通過

## 5. 清理 dead code

- [x] 5.1 移除 `Config.reset_mode` 欄位
  - 打開 `core/src/lib/config.zig`，定位 Config struct (行 14)
  - 移除 `reset_mode: bool` 欄位宣告
  - 移除相關的初始化邏輯（如有）
  - 檢查無其他使用處
  - 驗證編譯和測試通過

## 6. 改進 socket poll 邏輯

- [x] 6.1 引入具名索引常數或註解
  - 在 main.zig 頂部或 runEventLoop() 函數內定義 `const STDIN_FD_INDEX = 0` 等常數
  - 或在 pollfds 初始化處添加清晰註解說明索引含義
  - 修改 `const socket_index = ...` 為使用具名常數
  - 驗證編譯無誤

## 7. 集成測試和驗證

- [x] 7.1 執行單元測試
  - 運行 `zig build test`
  - 確保所有測試通過

- [x] 7.2 編譯和基本功能測試
  - 運行 `zig build`
  - 執行 `zig build run -- --minutes 1`
  - 驗證計時器正常倒數

- [x] 7.3 手動功能驗證
  - 測試 `--help` 選項是否正常顯示幫助
  - 測試 `-s 30` 和 `-m 2` 參數解析
  - 測試 `q` 鍵是否正確退出（TTY 模式）

## 8. 提交和清理

- [x] 8.1 建立獨立 git commits
  - Commit 1: 提取 main() 函數（setupRawMode, findUiCwd, setupSocket, runEventLoop）
  - Commit 2: 修正 updateTimer() heap dupe
  - Commit 3: 移除 Config.reset_mode
  - Commit 4: 改進 socket poll 邏輯（已包含在 Commit 1）

- [x] 8.2 提交訊息格式
  - 使用 `refactor: <description>` 格式
  - 每個 commit 附加 co-author 簽名

- [x] 8.3 確認所有改動完成
  - 最終執行 `zig build test` 驗證
  - 檢查 git log 確認 commits 已提交
