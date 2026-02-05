## 1. API Investigation

- [x] 1.1 使用 zig-std-index 查詢 `std.Io` 相關 API（替代 `poll`）
- [x] 1.2 記錄可行的 stdin 事件等待/輪詢方案與限制

## 2. Core Implementation

- [x] 2.1 更新 `core/src/main.zig` 的 stdin 輪詢初始化流程以符合 Zig master
- [x] 2.2 調整相關 I/O 使用點，確保行為與舊版一致

## 3. Verification

- [x] 3.1 在 Zig master 執行 `zig build run -- --seconds 3` 驗證可成功編譯與執行
