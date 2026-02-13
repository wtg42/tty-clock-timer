## Context

Core 主流程已切換為 `main(init: std.process.Init)`，且 runtime allocator 實際來源已改用 `init.gpa`。
目前仍保留 `core/src/lib/allocator.zig` 的 `AllocatorCtx` 與其測試，形成「已不在 runtime 使用、但仍存在程式碼」的雙軌狀態。
這會增加維護負擔，並讓讀者誤判 allocator 策略是否仍由專案自定義。

## Goals / Non-Goals

**Goals:**
- 明確 Core runtime allocator 的單一來源為 `std.process.Init` 提供的 allocator（現階段 `init.gpa`）。
- 移除不再使用的自定義 allocator 模組，避免冗餘與認知分歧。
- 保持既有 CLI、timer、IPC 功能行為不變。

**Non-Goals:**
- 本次不實作 `init.arena` 分流與長生命週期優化。
- 不調整 timer state machine、IPC protocol 或 TUI 呈現邏輯。
- 不引入新的 allocator abstraction layer。

## Decisions

- 決策 1：runtime allocator 以 `init.gpa` 為唯一來源
  - Rationale：與 Zig std 的 `Init` 生命週期與預設行為一致，減少重複管理成本。
  - Alternative：保留 `AllocatorCtx`；可自訂策略，但現況已與 runtime 脫鉤，繼續保留價值低。

- 決策 2：移除 `core/src/lib/allocator.zig`
  - Rationale：該模組不再被主流程依賴，保留只會造成策略歧義。
  - Alternative：先保留並加註 deprecated；可降低一次性變更幅度，但會延長雙軌期。

- 決策 3：以回歸測試確保語意不變
  - Rationale：allocator 來源調整屬內部策略變更，應以 `zig build test` + CLI smoke test 驗證功能等價。
  - Alternative：僅依編譯通過判斷；風險是漏掉行為層退化。

## Risks / Trade-offs

- [Risk] 失去舊 `AllocatorCtx` 在不同 build mode 的明確切換敘述 → Mitigation：於文件明示目前使用 `init.gpa`，後續若需再引入 `init.arena` 分流另開 change。
- [Risk] 刪除模組後若仍有隱性引用會造成編譯失敗 → Mitigation：以全域搜尋與 `zig build test` 驗證。
- [Trade-off] 先不做 arena 分流可降低本次風險，但長生命週期最佳化延後 → Mitigation：將階段二（arena 分流）列入後續 change。

## Migration Plan

1. 確認 `core/src/main.zig` allocator 來源統一為 `init.gpa`。
2. 移除 `core/src/lib/allocator.zig` 並清理引用。
3. 更新 README 與註解中的 allocator 策略描述。
4. 執行 `zig build test` 與最小 smoke test 驗證。

## Open Questions

- 階段二是否要將部分長生命週期資料改由 `init.arena` 管理，並建立明確分配準則（短生命週期用 `gpa`、長生命週期用 `arena`）。
