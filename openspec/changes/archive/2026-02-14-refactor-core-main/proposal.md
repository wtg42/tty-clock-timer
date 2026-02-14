## Why

`core/src/main.zig` 目前約 310 行，混合了 termios 配置、socket 管理、事件循環等多個職責，使得代碼難以理解和維護。同時，IPC 層有不必要的記憶體配置、dead code，以及不直觀的 socket poll 邏輯。重構這些部分將大幅提升代碼質量，使未來的改動更容易進行。

## What Changes

- **拆分 `main()` 函數**：提取 `setupRawMode()`、`setupSocket()`、`findUiCwd()`、`runEventLoop()` 等獨立函數，讓主流程從 ~310 行縮減到 ~40 行
- **移除不必要的 heap 複製**：修正 `updateTimer()` 中對 status 字串的多餘 `allocator.dupe()`（該字串來自 comptime 字面量）
- **清除 dead code**：刪除 `Config.reset_mode` 未使用欄位，減少維護負擔
- **澄清 socket poll 邏輯**：改進 stdin/socket index 計算方式，使其更直觀

## Capabilities

### New Capabilities

無新功能，此次為代碼質量改進。

### Modified Capabilities

無需求變更，僅涉及實作細節優化。

## Impact

- **受影響代碼**：
  - `core/src/main.zig`（主要）
  - `core/src/lib/config.zig`（移除未使用欄位）
  - `core/src/lib/ipc.zig`（修正 updateTimer()）

- **API 變更**：無（所有改動為內部重構）
- **外部使用者影響**：無（行為完全相同）
