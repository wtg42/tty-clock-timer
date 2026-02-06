## 1. 計時核心 API 遷移

- [x] 1.1 在 `core/src/lib/timer.zig` 移除 `std.time.Timer` 依賴，改用 Zig master 可用時間來源（`std.Options.debug_io.now(.awake)`）。
- [x] 1.2 以時間戳差值重寫 `start`、`pause`、`unpause`、`update`、`reset` 的內部狀態更新流程，確保 remaining 以飽和邏輯遞減至 0。

## 2. 相容性與行為驗證

- [x] 2.1 更新 timer 相關測試或斷言，覆蓋 running/paused/finished 狀態轉換與時間遞減語意。
- [x] 2.2 執行 `zig fmt core/src/*.zig core/src/lib/*.zig`、`zig build test`、`zig build run -- --seconds 3`，確認 Zig master 下編譯與執行成功。
