## Context

目前 core runtime 已採用 `std.process.Init` 提供的 `init.gpa` 作為主要 allocator，但 I/O 初始化仍由 `main.zig` 手動建立 `std.Io.Threaded`。
這使 runtime 資源來源分散：allocator 走 Init，io 走手動建構，造成初始化責任重疊與維護負擔。

## Goals / Non-Goals

**Goals:**
- 將 core runtime 的 I/O 初始化統一為 `std.process.Init` 提供的 `init.io`。
- 維持既有 CLI 可觀察行為（help/error 輸出語意、timer 執行流程、exit code）。
- 讓 `main.zig` 初始化步驟更一致，降低 Zig master API 變動造成的風險。

**Non-Goals:**
- 不重寫 timer 狀態機或 IPC 協定。
- 不新增 CLI 旗標或改變參數解析規則。
- 不在此變更中重新設計整體 logging/IO abstraction。

## Decisions

- 以 `init.io` 直接取代手動 `std.Io.Threaded.init(...)`。
  - 理由：`std.process.Init` 已封裝執行期環境資源，沿用其 io 可減少重複初始化。
  - 替代方案：保留手動 `Threaded`，僅補充註解。此方案無法解決資源來源不一致問題，因此不採用。
- 保持現有輸出 writer 使用路徑，僅調整其底層 io 來源。
  - 理由：可在最小行為變更下完成遷移，降低回歸風險。
  - 替代方案：同時重構輸出層 abstraction。此方案範圍過大，超出本次變更。
- 以編譯與既有測試作為回歸保護。
  - 理由：此變更屬初始化路徑調整，最有效驗證是 `zig build` 與 `zig build test`。

## Risks / Trade-offs

- [Risk] `init.io` 與手動 `Threaded` 在預設 buffering/flush 行為上有微差異 → Mitigation：保留既有輸出流程並執行 core build/test 驗證。
- [Risk] 初始化順序調整可能引入 early error path 行為差異 → Mitigation：檢查 no-arg help、invalid-arg error 及一般倒數流程。
- [Trade-off] 選擇小步遷移，不同時處理其他 runtime 資源重構 → Mitigation：後續可獨立提案處理 `arena`/`environ_map` 等整合。
