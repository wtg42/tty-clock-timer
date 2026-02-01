## Context

`core/src/main.zig` 的流程註解包含過期 TODO，與現有主迴圈、timer 初始化與 IPC 更新的實作不一致。

## Goals / Non-Goals

**Goals:**
- 更新流程註解，準確描述現有行為
- 移除過期 TODO 描述以避免誤導

**Non-Goals:**
- 不更動任何程式邏輯
- 不調整 timer 或 IPC 行為

## Decisions

### Decision 1: 僅更新註解文字

此變更僅涉及註解內容，避免引入實作風險，並保持變更範圍可控。
