## Context

目前 `tui-timer-display` 能顯示 ASCII 倒數與 timer 狀態，但缺少 ETA（預計結束時間）資訊，使用者需自行心算。此變更採用 Core 提供 ETA 的方式，將 ETA 作為 IPC 事件的一部分傳給 TUI，避免在 UI 端各自推算造成語義分歧。

## Goals / Non-Goals

**Goals:**
- 在倒數主畫面提供可讀的 ETA 文案，格式為 `ETA HH:MM`。
- 在不同 timer 狀態（至少 running、paused）提供一致且可預期的 ETA 顯示規則。
- 維持既有倒數主顯示、狀態與快捷鍵提示的可讀性。

**Non-Goals:**
- 不調整現有控制鍵映射與主倒數 rendering 架構。
- 不導入時區切換、日期跨天顯示策略或國際化字串系統。
- 不重構整體首頁版面，只做 ETA 相關最小必要調整。

## Decisions

- ETA 由 Zig Core 計算並透過 IPC 下發（例如在 `update_timer` 事件加入 `eta_hhmm` 欄位）。
  - 理由：Core 作為單一真相來源（single source of truth），可避免 UI 端推算造成行為差異。
  - 替代方案：TUI 本地推算。未採用，因 paused/重跑語義較易漂移且不易一致。
- ETA 顯示格式固定為 `ETA HH:MM`（24-hour、到分、不顯示秒）。
  - 理由：符合需求且降低字串噪音。
- 不使用 Emoji 或鬧鐘字元。
  - 理由：避免 Linux 終端字體覆蓋差異導致寬度/可讀性不一致。
- paused 時顯示凍結的 ETA 時刻，不持續更新。
  - 理由：符合需求「paused 時間凍結」。
- timer 開始或重跑時重新計算 ETA（包含初始開始、resume、reset 後再次運行）。
  - 理由：確保 ETA 反映新的計時起點。
- ETA 以單行輔助資訊放在倒數主顯示下方，保留原有 controls/status 位置。
  - 理由：降低版面衝突風險，維持原有閱讀動線。

## Risks / Trade-offs

- [Risk] Core 所在系統時間被手動調整可能導致 ETA 跳動 → Mitigation：將 ETA 定位為輔助資訊，核心倒數仍以 remaining 秒數為準。
- [Risk] 小尺寸 terminal 可能發生行擠壓 → Mitigation：ETA 文案保持短字串，必要時優先保留倒數主字與控制提示。
- [Trade-off] Core 與 TUI 需一起更新 IPC schema → Mitigation：透過 type guard 與回歸驗證確保相容性。
