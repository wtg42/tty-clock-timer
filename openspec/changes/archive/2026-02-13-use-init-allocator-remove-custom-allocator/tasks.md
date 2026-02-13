## 1. Runtime allocator 單一化

- [x] 1.1 確認 `core/src/main.zig` 全程使用 `std.process.Init` 提供的 allocator（`init.gpa`）並移除舊 allocator context 依賴
- [x] 1.2 全域檢查 `core/src`，清理 `allocator_ctx` / `AllocatorCtx` 相關引用與 import

## 2. 移除舊模組與文件對齊

- [x] 2.1 移除 `core/src/lib/allocator.zig`（含其 inline tests）
- [x] 2.2 更新 `core/README.md` 與根目錄 `README.md` 中 allocator 策略描述，對齊現況（以 `init.gpa` 為主）

## 3. 驗證

- [x] 3.1 執行 `zig build test`（於 `core/`）確認回歸通過
- [x] 3.2 執行 `zig build run -- --seconds 1` smoke test，確認主流程可啟動並維持既有行為
