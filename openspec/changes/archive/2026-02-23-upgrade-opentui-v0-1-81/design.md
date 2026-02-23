## Context

目前 TUI 依賴 `@opentui/core` 與 `@opentui/solid` v0.1.80。v0.1.81 修正了數個 bug，屬於相容升級。

## Goals / Non-Goals

**Goals:**
- 升級 `tui/package.json` 中的版本至 `^0.1.81`
- 執行 `bun install` 更新 lockfile
- 驗證 bundle build 與基本功能正常

**Non-Goals:**
- 使用 v0.1.81 新 API
- 修改任何應用程式邏輯

## Decisions

- **直接修改版本號**：`^0.1.80` → `^0.1.81`，不使用 `bun update` 指令，避免意外升級其他套件

## Risks / Trade-offs

- v0.1.81 尚無新增依賴（與 v0.1.80→v0.1.80 升級時引入 tree-sitter 不同），風險極低
