## Why

OpenTUI v0.1.81 修正了多個 bug，包括渲染 idle state 掛起問題、UTF-8/CJK 文字包裝錯誤、以及 streaming reset 問題，提升穩定性。

## What Changes

- 將 `@opentui/core` 從 `^0.1.80` 升級至 `^0.1.81`
- 將 `@opentui/solid` 從 `^0.1.80` 升級至 `^0.1.81`
- 更新 `tui/bun.lockb`（lockfile）

## Capabilities

### New Capabilities
<!-- 無新增 capability -->

### Modified Capabilities
- `tui-bundle-build`: 驗證升級後的 bundle build 流程仍正常運作

## Impact

- `tui/package.json`：版本號變更
- `tui/bun.lockb`：lockfile 更新
- 無 API 或 IPC 格式變更
- 無 breaking changes
