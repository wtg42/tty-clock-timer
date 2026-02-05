## Why

目前 Zig master 的 `std.Io` 已無 `poll` 成員，導致 `zig build run` 直接編譯失敗，阻斷核心 CLI 的基本使用與後續開發流程。需要修正以維持與 Zig master 的相容性。

## What Changes

- 更新 core 內使用 `std.Io` 的位置，改用現行 Zig master 支援的 API，避免編譯失敗。
- 確保 stdin 監聽/非阻塞讀取流程在新 API 下行為一致。

## Capabilities

### New Capabilities
- `build-compatibility`: 確保在 Zig master 上可成功編譯與執行核心 CLI

### Modified Capabilities
- （無）

## Impact

- 影響 `core/src/main.zig`（stdin 事件輪詢與 I/O 初始化）
- 影響 Zig master API 相容性
