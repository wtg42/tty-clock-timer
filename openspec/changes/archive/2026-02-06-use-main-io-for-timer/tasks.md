## 1. Timer 介面與時間來源調整

- [x] 1.1 更新 `core/src/lib/timer.zig`：將 `start`、`unpause`、`update` 等需取時間的方法改為接收 `io: std.Io`，並移除 `std.Options.debug_io` 依賴。
- [x] 1.2 調整 timer 內部 `nowTimestamp` 與 elapsed 計算路徑，確保時間一律從注入的 `io` 取得且既有倒數語意不變。

## 2. 呼叫點與測試同步

- [x] 2.1 更新 `core/src/main.zig` 的 timer 呼叫點，使用 `main` 已建立的 `io` 傳入 `countdown_timer.start(...)` 與 `countdown_timer.update(...)`。
- [x] 2.2 更新 timer 相關測試以符合新簽名，並執行 `zig fmt src/*.zig src/lib/*.zig`、`zig build test`、`zig build run -- --seconds 3` 驗證。
