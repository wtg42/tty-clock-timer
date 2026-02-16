## Context

`main.zig` 目前包含：
- **第 1-15 行**：模組引入和常數定義
- **第 17-49 行**：輔助函數（helpMessage, timerStateToStatus, configErrorMessage 等）
- **第 51-217 行**：五個中等規模的函數（handleStdinInput, sendTimerProjection 等）
- **第 219-528 行**：`main()` 函數，包含 10 個邏輯步驟

主要問題：
1. `main()` 約 310 行，混合初始化、socket 管理、事件循環邏輯
2. 新開發者難以理解整體流程和職責邊界
3. `ipc.zig` 的 `updateTimer()` 對 comptime 字面量進行不必要的 heap dupe
4. `Config.reset_mode` 宣告但未使用
5. socket poll 中的 stdin/socket index 計算缺乏直觀性

## Goals / Non-Goals

**Goals：**
- 將 `main()` 的邏輯骨架清晰化，縮減到 ~40 行主流程
- 提取獨立函數：`setupRawMode()`、`setupSocket()`、`findUiCwd()`、`runEventLoop()`
- 消除 `updateTimer()` 中的不必要 heap 配置
- 移除 `Config.reset_mode` dead code
- 改進 socket poll 邏輯的可讀性
- 保持完全向後兼容——所有行為不變

**Non-Goals：**
- 不改變 timer 核心邏輯或 IPC 訊息格式
- 不涉及 server/tui 層次的架構變更
- 不優化計時器計算精度或 socket 吞吐量

## Decisions

### 1. main() 函數拆分策略

**決定**：於 `main.zig` 內提取 4 個新函數，保持單一文件結構。

**選項對比**：
- ✅ **單文件內拆分**（採用）：termios/socket 邏輯是 main 專屬的 orchestration，不被其他模組複用；保持 main.zig 為完整單位
- ❌ 移到新的 `lib/main-orchestrator.zig`：增加層級複雜度，跨文件依賴反而不清
- ❌ 移到 `lib/` 當前內的現有模組：這些邏輯不屬於 config/timer/ipc 職責

**提取的函數**：
- `setupRawMode(io, stderr_writer) -> RawModeContext`：管理 termios，回傳上下文結構
- `findUiCwd(io) -> ?[]const u8`：三個候選位置搜尋
- `setupSocket(io, stderr_writer) -> SocketServerContext`：建立 unix socket 並回傳上下文
- `runEventLoop(...) -> void`：主事件循環邏輯（~130 行），包含 poll 和訊息處理

### 2. updateTimer() 記憶體配置修正

**決定**：移除 `allocator.dupe(u8, status)` 調用

**分析**：
- `status` 來自 `timerStateToStatus()` 回傳的 comptime 字面量（`"idle"`, `"running"` 等）
- `sendMessage()` 立即序列化成 JSON，不會延長 Message 存活期
- 每秒調用一次，每次無謂的 heap 配置/釋放

**實施**：
```zig
// 修前
const status_dup = try allocator.dupe(u8, status);
defer allocator.free(status_dup);
try sendMessage(allocator, writer, Message{ .update_timer = .{ .status = status_dup } });

// 修後
try sendMessage(allocator, writer, Message{ .update_timer = .{
    .remaining_seconds = ...,
    .total_duration = ...,
    .status = status,  // 直接使用 comptime 字面量
} });
```

### 3. Config.reset_mode 移除

**決定**：刪除未使用欄位

**理由**：
- 宣告但無初始化邏輯、無使用處
- 保留維護負擔（future-proofing 反模式）
- 若真需要標誌，應於實際使用時再加

### 4. Socket poll 邏輯澄清

**決定**：引入具名索引常數或註解，替代隱含計算

**現狀**：
```zig
const socket_index: usize = if (read_stdin) 1 else 0;
// pollfds[0] 隱含為 stdin，pollfds[1] 根據條件為 socket
```

**改進**：
```zig
const STDIN_FD_INDEX: usize = 0;
const SOCKET_FD_INDEX: usize = 1;
// 或更清晰的 pollfds 結構化配置
```

## Risks / Trade-offs

| 風險 | 風險等級 | 緩解策略 |
|------|---------|--------|
| 新增的中間函數增加棧深度 | 低 | Zig 編譯器會內聯，實際無性能損失；測試驗證 |
| 函數簽名冗長（io, stderr_writer, allocator 等參數） | 低 | 使用結構體封裝相關參數（e.g., `RawModeContext`、`SocketServerContext`） |
| 移除 `reset_mode` 時未來重新引入困難 | 低 | 該欄位本未使用過，若未來需要直接加回即可 |
| updateTimer() 修改影響其他使用處 | 低 | 僅用於 main() 的 `sendTimerProjection()` 內部，grep 驗證無其他呼叫 |

## Migration Plan

**方案**：逐項實施，每項提交一個獨立 commit
1. 提取 `setupRawMode()`、`setupSocket()` 等函數，保持 main() 主邏輯不變
2. 修正 `updateTimer()` heap dupe
3. 移除 `Config.reset_mode`
4. 澄清 socket poll 索引邏輯

**測試**：
- 編譯檢查：`zig build`
- 執行測試：`zig build test`
- 手動驗證：`zig build run -- --minutes 1`

**回滾**：若任何項目引入 regression，回滾單一 commit 即可（獨立性設計）

## Open Questions

- 是否需要為新提取函數編寫單元測試？（建議：否，因為它們是 main 的內部實作細節，集成測試已覆蓋）
- `RawModeContext` / `SocketServerContext` 是否應做為公開結構體，或保持私有？（建議：私有，main.zig 內部使用）
