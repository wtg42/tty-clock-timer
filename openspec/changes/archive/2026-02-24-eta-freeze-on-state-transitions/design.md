## Context

目前 Core 在每次事件迴圈推送 `update_timer` 時，都會以「當下 `real.now().toSeconds()` + `remaining_seconds`」重新推算 ETA。由於 `remaining_seconds` 來自 `remaining_ns` 的秒級截斷，且 wall clock 也被截斷到秒，接近 minute boundary 時可能出現提早一分鐘的顯示漂移。現有 paused 凍結語義已存在，但 running 期間仍持續重算，導致 ETA 穩定性不足。

## Goals / Non-Goals

**Goals:**
- 將 ETA 語義收斂為「事件驅動重算、週期內凍結」，只在 `start`、`resume`、`reset` 重算。
- running 與 paused 期間皆回傳 frozen ETA，避免每 tick 重算造成漂移。
- 補齊 minute boundary 測試，覆蓋邊界時間不漂移情境。
- 維持現有 IPC payload 介面相容（`eta_hhmm` 欄位與 `HH:MM` 格式不變）。

**Non-Goals:**
- 不變更 TUI Store/Renderer 架構與顯示版面。
- 不新增 IPC 欄位、不引入新 command。
- 不重構整體 timer state machine；僅調整 ETA projection 策略。

## Decisions

1. 採用「狀態轉換事件重算」而非「每 tick 推算」
   - 選擇：在 `start`、`resume`、`reset` 時更新 frozen ETA；其餘時間仅读取。
   - 理由：ETA 本質是本輪倒數的預計結束時刻，應在週期起點確定，而非隨渲染頻率波動。
   - 替代方案：維持每 tick 重算並嘗試四捨五入修補。未採用，因仍受多次截斷與 clock sampling 影響，行為較難保證。

2. 保留 paused 凍結語義，並與 running 凍結策略對齊
   - 選擇：paused 仍沿用 frozen ETA，不觸發重算。
   - 理由：符合既有使用者預期，也避免 pause/unpause 邏輯分裂。
   - 替代方案：paused 另存獨立欄位。未採用，會增加狀態同步成本且無額外價值。

3. 以測試鎖定 minute boundary 穩定性
   - 選擇：新增針對邊界秒數與狀態轉換的單元測試案例。
   - 理由：此問題容易回歸，且僅靠人工觀察難以穩定重現。
   - 替代方案：僅以整合測試驗證 UI 顯示。未採用，排障成本較高且定位不精準。

## Risks / Trade-offs

- [Risk] reset 在 running 中重啟週期時若漏觸發重算，會沿用舊 ETA → Mitigation：在 command 處理與 ETA projection 測試中加入 reset 專屬案例。
- [Risk] frozen ETA 與倒數秒數在視覺上不完全同步（秒級跳動 vs 分級顯示）→ Mitigation：規格明確定義 ETA 為「結束時刻（到分）」而非逐秒剩餘推導值。
- [Risk] 時間來源混用（monotonic vs real clock）造成認知混淆 → Mitigation：設計文件與 spec 明確區分：倒數遞減使用 monotonic，ETA 顯示使用 real deadline 投影。

## Migration Plan

1. 先更新 spec delta，固定 ETA 行為契約。
2. 調整 Core ETA projection 的重算觸發點與讀取策略。
3. 新增並通過 minute boundary 與狀態轉換測試。
4. 以現有 TUI 流程驗證相容性（無需調整 IPC schema）。

回滾策略：若上線後發現相容問題，可暫時回退至舊版 ETA 投影邏輯，但保留新測試草案以利後續修正。

## Open Questions

- 是否需要在文件中額外定義「跨日」顯示語義（例如 ETA 超過 24 小時仍僅顯示 `HH:MM`）？目前沿用既有行為。
