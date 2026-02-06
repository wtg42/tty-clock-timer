## Context

目前 `core/src/lib/timer.zig` 使用 `std.time.Timer`，但在 Zig master 該型別已移除，造成 `zig build run` 直接失敗。此變更需在不改變 CLI 對外行為的前提下，將計時邏輯遷移到 Zig master 現行可用 API，並維持倒數狀態機（idle/running/paused/finished）語意與測試穩定性。

## Goals / Non-Goals

**Goals:**
- 在 Zig master 上恢復可編譯、可執行的倒數流程。
- 以 monotonic 時間來源重建內部 elapsed 計算，避免 wall-clock 漂移影響。
- 保持既有公開行為與輸出格式（MM:SS、控制流程）不變。
- 讓 timer 測試可驗證狀態轉換與時間遞減語意，不依賴已刪除 API。

**Non-Goals:**
- 不新增使用者可見功能（例如新 CLI 旗標或新 UI 行為）。
- 不重構整個 timer 模組為全新架構。
- 不引入任何外部套件或非 std 的計時依賴。

## Decisions

1. 以 `std.Options.debug_io.now(.awake)` 作為時間來源
- 理由：`std.time.Timer` 已移除；`Io` 時間 API 為現行可用且具 monotonic 意義（`awake`）。
- 替代方案：
  - 直接使用 `std.posix.clock_gettime`：較底層、跨平台抽象較差，增加平台分支負擔。
  - 使用 `.real` 時鐘：會受系統時間調整影響，不適合倒數內部 elapsed。

2. 內部狀態由「Timer 物件」改為「上一個時間戳」
- 理由：倒數需要的是每次 update 的經過時間差；保存 `last_tick`（`?std.Io.Timestamp`）即可支援 start/pause/unpause/reset。
- 替代方案：每次 update 只讀 now 並以全域起始點回推，會使 pause/unpause 邏輯更複雜且易錯。

3. 以飽和減法更新剩餘時間
- 理由：elapsed 可能大於 remaining，需避免 underflow，確保最小值為 0。
- 替代方案：使用錯誤聯集數學函式後 `catch`，可行但語意不如明確飽和減法直觀。

4. 保持公開 API 介面不變，僅調整內部實作
- 理由：減少對 `main.zig` 與 TUI 整合層的影響，將修復範圍收斂於 `timer.zig`。
- 替代方案：重命名或改動函式簽名，會增加連鎖修改與回歸風險。

## Risks / Trade-offs

- [Risk] `debug_io` 在特定環境回傳解析度不足，導致短時間測試偶發不穩定。 → Mitigation：測試以狀態轉換與非嚴苛時間斷言為主，避免依賴極小時間差。
- [Risk] pause/unpause 邊界時序錯誤造成額外扣時。 → Mitigation：在 pause 前先 update，unpause 時重設 `last_tick` 為當下。
- [Risk] i96/u64 轉換處理不當導致溢位或負值問題。 → Mitigation：集中實作安全轉換邏輯，對負值視為 0、對過大值做上限處理。

## Migration Plan

1. 替換 `timer.zig` 內部欄位與時間讀取邏輯（移除 `std.time.Timer` 依賴）。
2. 調整 `start/pause/unpause/update/reset` 以時間戳差值驅動。
3. 執行 `zig fmt` 與 timer 相關測試，再跑 `zig build run -- --seconds 3` 驗證修復。
4. 若行為異常，回退到前一提交並保留 proposal/design 供再次修正（artifact 不回退）。

## Open Questions

- 是否需要在後續變更中提供可注入時間來源（test clock）以讓測試完全 deterministic？
- `.awake` 是否要在文件中明確定義為本專案 timer 的標準時鐘選擇？
