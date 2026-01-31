## Why

核心功能的測試覆蓋率偏低，導致缺失或回歸難以及時被發現。現在補齊測試範例與邊界情境，可降低後續重構與功能擴充的風險。

## What Changes

- 盤點 core 現有功能缺口與風險場景。
- 擴充單元測試範例，提升覆蓋率與錯誤路徑驗證。
- 明確標記目前未被測到的行為或輸入邊界。

## Capabilities

### New Capabilities
- `core-test-coverage`: 定義 core 測試覆蓋率提升的要求與驗證範圍
### Modified Capabilities

## Impact

- core/src/lib/config.zig
- core/src/lib/timer.zig
- core/src/lib/ipc.zig
- core/src/main.zig
