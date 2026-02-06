## Why

目前專案在 Zig master 無法編譯，原因是 `std.time.Timer` 已自標準庫移除，導致 `core/src/lib/timer.zig` 直接失效。此問題會阻斷 `zig build run` 與後續開發驗證，必須先恢復與 Zig master 的相容性。

## What Changes

- 將倒數計時器的時間來源從已移除的 `std.time.Timer` 改為 Zig master 可用的時間 API（例如 `std.Io` 時間戳）。
- 保留既有倒數行為語意：`start`、`pause`、`unpause`、`update`、`reset`、`isFinished` 在使用者觀點維持一致。
- 更新或補強 timer 相關測試，確保編譯修復同時不回歸核心狀態機行為。

## Capabilities

### New Capabilities
- 無。

### Modified Capabilities
- `build-compatibility`: 更新需求以確保 core 在 Zig master 上不依賴已移除的 `std.time.Timer`，並可成功建置與執行倒數流程。

## Impact

- Affected code: `core/src/lib/timer.zig`（主要）、可能包含 `core/src/main.zig` 與相關測試區塊。
- APIs/behavior: CLI 參數與對外介面預期不變，主要為內部時間實作調整。
- Dependencies: 無新增外部依賴；僅改用 Zig std 現行可用 API。
- Systems: 影響 core build/run 與 timer 狀態更新路徑。
