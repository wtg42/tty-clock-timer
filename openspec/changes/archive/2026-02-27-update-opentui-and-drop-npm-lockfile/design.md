## Context

`tui/` 目前使用 Bun 作為主要開發工具，但倉庫內同時存在 `bun.lock` 與 `package-lock.json`。在 OpenTUI 快速迭代下，若依賴來源不唯一，容易發生「宣告版本已更新但實際安裝版本不同」的問題，增加協作與 CI 重現成本。

## Goals / Non-Goals

**Goals:**
- 建立 `tui/` 依賴管理的單一事實來源（`bun.lock`）。
- 將 OpenTUI 套件更新到最新穩定版本並可重現安裝結果。
- 讓後續升級流程可預測，且能快速驗證是否可用。

**Non-Goals:**
- 不變更 TUI 功能或互動行為。
- 不導入新的 package manager 或多工具混用策略。
- 不處理與 `tui/` 無關的 lockfile 政策。

## Decisions

1. 採用 Bun-only 鎖檔策略
   - 決策：`tui/` 僅保留 `bun.lock`，移除 `package-lock.json`。
   - 理由：避免 npm 與 Bun 雙 lockfile 漂移，降低版本分歧。
   - 替代方案：保留雙 lockfile 並定期同步。
   - 未採用原因：同步成本高，且在快速迭代套件上易失效。

2. OpenTUI 套件版本跟進最新穩定版
   - 決策：`@opentui/core`、`@opentui/solid` 更新到最新穩定版（本次為 `0.1.84`）。
   - 理由：OpenTUI 尚未 `1.0`，功能與行為調整頻繁，持續跟進可減少大幅落後升級風險。
   - 替代方案：固定舊版並長期不動。
   - 未採用原因：技術債累積，後續升級風險更大。

3. 建立最小驗證流程作為升級門檻
   - 決策：依賴更新後至少驗證 `bun install`、`bun run build`、`bun test`。
   - 理由：在不擴大範圍下確保可建置與基本行為穩定。
   - 替代方案：僅更新 lockfile 不驗證。
   - 未採用原因：無法及早發現 API 或相依差異導致的回歸。

## Risks / Trade-offs

- [風險] OpenTUI 小版本可能帶來行為差異 → [緩解] 每次更新後執行 build/test 與基本互動 smoke test。
- [風險] 團隊成員誤用 npm 重新產生 `package-lock.json` → [緩解] 在文件明確標註 Bun-only 並於 review 阻擋新增 npm lockfile。
- [取捨] 捨棄 npm lockfile 可能降低跨工具彈性 → [緩解] 以一致性與可重現性優先，必要時再評估完整遷移策略。

## Migration Plan

1. 確認 `tui/package.json` 的 OpenTUI 版本已更新。
2. 以 Bun 更新並刷新 `tui/bun.lock`。
3. 移除 `tui/package-lock.json`。
4. 執行 `bun install`、`bun run build`、`bun test` 驗證。
5. 將 Bun-only 準則寫入開發文件，避免回歸雙 lockfile。

## Open Questions

- 是否要在 CI 新增檢查，當 `tui/package-lock.json` 出現時直接 fail？
- OpenTUI 版本更新頻率是否固定為每次 release 跟進，或採週期性批次更新？
