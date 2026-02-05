## Context

目前 `core/src/main.zig` 內部使用 `std.Io.poll` 初始化 stdin 輪詢，但 Zig master 已移除此成員，導致編譯失敗。此變更需在不改變 CLI 行為的前提下，將 stdin 監聽流程改為 Zig master 支援的 I/O API。

## Goals / Non-Goals

**Goals:**
- 在 Zig master 上可成功編譯與執行 `tty_clock_timer`。
- 保持現有 stdin 監聽/非阻塞讀取行為一致。

**Non-Goals:**
- 不改變 CLI 參數或 timer 行為。
- 不引入新的外部依賴。

## Decisions

- 以 Zig master 現行 `std.Io` 能力替換 `poll`，實作等價的 stdin 事件等待機制。
  - **Rationale:** 避免依賴已移除的 API，保持與 upstream 相容。
  - **Alternatives:** 維持舊 API 並鎖定 Zig 版本（不符合專案目標）。
- 在實作前使用本地 zig-std-index 腳本確認 API 正確性。
  - **Rationale:** Zig master 變動快，避免推測造成編譯失敗。

## Risks / Trade-offs

- [Risk] 行為差異造成 stdin 讀取時序改變 → Mitigation：以現有 CLI 行為作基準，新增對等流程驗證或最小化變動範圍。
- [Risk] Zig master API 再次變動 → Mitigation：在 change 內記錄採用 API 與查詢結果，降低未來調整成本。
