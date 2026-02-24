## 1. Core ETA 事件擴充

- [x] 1.1 在 Core `update_timer` 事件 payload 新增 `eta_hhmm` 欄位（`HH:MM`，不含秒）
- [x] 1.2 實作 ETA 狀態規則：paused 凍結、開始/重跑（含 resume）後重算 ETA

## 2. TUI 型別與投影更新

- [x] 2.1 更新 `protocol`/`store` 型別與投影流程，消費 Core 提供的 `eta_hhmm`
- [x] 2.2 在倒數主顯示下方加入 ETA 資訊行，顯示格式固定為 `ETA HH:MM`

## 3. 驗證與回歸

- [x] 3.1 手動驗證 running 與 paused 的 ETA 顯示（paused 不變動）
- [x] 3.2 手動驗證開始/重跑後 ETA 會重算，且維持到分顯示
- [x] 3.3 執行 `bun run dev` 並檢查倒數、狀態、控制提示與 ETA 是否同步更新且無明顯閃爍
