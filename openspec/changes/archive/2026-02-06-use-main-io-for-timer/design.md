## Context

目前 `core/src/lib/timer.zig` 由 timer 模組內部直接使用 `std.Options.debug_io` 取得時間，而 `core/src/main.zig` 已在執行期建立 `std.Io.Threaded` 並使用其 `io` 實例處理 sleep、stdin 與 IPC。這種雙來源時間取得方式會讓時間語意與責任邊界不清楚，也增加未來維護與測試時的心智負擔。

## Goals / Non-Goals

**Goals:**
- 讓 timer 使用呼叫端注入的 `std.Io`，與 `main` 的執行期 `Io` 上下文一致。
- 保持現有倒數行為語意（start/pause/unpause/update/reset）不變。
- 保持 CLI 對外介面與 IPC 輸出不變，只調整內部時間取得路徑。
- 讓測試可覆蓋注入 `Io` 後的狀態轉換與遞減邏輯。

**Non-Goals:**
- 不新增任何使用者可見功能或 CLI 參數。
- 不重寫 timer 狀態機架構。
- 不引入外部計時依賴或非 std 的時間基礎設施。

## Decisions

1. 將 `CountdownTimer` 需要讀時間的方法改為顯式接收 `std.Io`
- 做法：`start`、`unpause`、`update` 改為帶入 `io: std.Io`（或透過內部 helper 轉發）。
- 理由：把時間來源控制權留在呼叫端，讓 timer 不再綁定 `std.Options.debug_io`。
- 替代方案：在 `CountdownTimer` 內儲存 `std.Io` 欄位。此做法會讓 init 與生命週期綁定更強，對現有 API 侵入較大。

2. `main` 統一以既有 `io` 實例呼叫 timer
- 做法：在 `main` 的 `countdown_timer.start(...)` 與 loop 內 `countdown_timer.update(...)` 傳入同一個 `io`。
- 理由：對齊主程式既有 I/O 模型，避免同一流程混用不同時鐘上下文。
- 替代方案：維持 `main` 無參數呼叫，timer 內自行選擇來源。此做法會延續不一致問題。

3. 維持計時演算法不變，只替換時間來源
- 做法：保留以 `last_tick` 與 elapsed delta 更新 `remaining_ns` 的邏輯，僅替換 `nowTimestamp` 的取得方式。
- 理由：降低回歸風險，將本次變更聚焦在注入與相容性。
- 替代方案：同時導入可插拔 clock abstraction。可測性更高，但超出本次需求範圍。

## Risks / Trade-offs

- [Risk] 方法簽名變更可能波及現有呼叫點與測試。 → Mitigation：先用搜尋完整更新呼叫點，再跑 `zig build test` 與 `zig build run -- --seconds 3`。
- [Risk] 測試環境若未提供可用 `Io`，可能增加測試 setup 複雜度。 → Mitigation：沿用既有 `std.Io.Threaded` 初始化模式，封裝最小化測試 helper。
- [Risk] 將 `Io` 傳遞到 timer 方法會稍增函式介面噪音。 → Mitigation：限制在必要方法，維持 `pause/reset/isFinished` 等不需 `Io` 的方法簽名不變。

## Migration Plan

1. 更新 `core/src/lib/timer.zig` 方法簽名與內部 `nowTimestamp` helper，移除 `std.Options.debug_io` 直接依賴。
2. 更新 `core/src/main.zig` 的 timer 呼叫點，傳入 `main` 已建立的 `io`。
3. 調整 timer 相關測試以符合新簽名，確保狀態與遞減語意一致。
4. 執行 `zig fmt src/*.zig src/lib/*.zig`、`zig build test`、`zig build run -- --seconds 3` 驗證。

## Open Questions

- 是否在後續 change 將時間來源進一步抽象成可替換 clock，以提升 deterministic test 能力？
- 是否需要在 `build-compatibility` 主規格補充「所有時間讀取應優先使用執行期注入 `Io`」的通則？
