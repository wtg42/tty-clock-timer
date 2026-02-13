## Why

Core 目前同時具備 `std.process.Init` 內建 allocator 與專案自定義 `AllocatorCtx`，造成 allocator 策略重複且增加維護成本。
既然 runtime 已改為使用 `main(init: std.process.Init)` 的 allocator，應同步移除不再使用的自定義實作，避免未來認知分歧。

## What Changes

- 明確將 Core runtime allocator 策略定義為使用 `std.process.Init` 提供的 allocator（現階段以 `init.gpa` 為主）。
- 移除不再被 runtime 使用的 `core/src/lib/allocator.zig` 與相關測試。
- 清理文件與註解中對舊 allocator 流程的描述，確保說明與程式行為一致。

## Capabilities

### New Capabilities
- `core-init-allocator-strategy`: 定義 Core 在主流程中應使用 `std.process.Init` 提供之 allocator，並移除舊有自定義 allocator 依賴。

### Modified Capabilities
- （無）

## Impact

- Affected code: `core/src/main.zig`、`core/src/lib/allocator.zig`（移除）。
- Affected docs: `core/README.md`、專案根目錄 `README.md`（如有 allocator 策略描述需同步）。
- Affected tests: `core/src/lib/allocator.zig` 既有測試將隨檔案移除，並以整體 `zig build test` 回歸驗證。
