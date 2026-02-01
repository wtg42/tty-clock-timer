## Why

`core/src/main.zig` 的流程註解已落後於實作，容易誤導讀者對主流程完成度的理解。更新註解可維持文件與實作一致，降低維護成本。

## What Changes

- 更新 `main()` 流程註解中的過期 TODO
- 讓註解描述與實際主迴圈行為一致
- 不改動任何邏輯或行為

## Capabilities

### New Capabilities
- `main-flow-docs`: 主流程註解與實作一致

### Modified Capabilities

## Impact

- `core/src/main.zig`: 更新流程註解文字
