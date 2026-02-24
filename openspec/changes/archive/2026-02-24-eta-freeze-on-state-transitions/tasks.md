## 1. ETA 投影語義調整

- [x] 1.1 盤點 `core/src/main.zig` 目前 ETA projection 生命週期，標記 `start`、`resume`、`reset` 三個重算觸發點與 running/paused 只讀路徑。
- [x] 1.2 重構 ETA projection 狀態欄位與流程，確保僅在 `start`、`resume`、`reset` 重算 frozen ETA。
- [x] 1.3 調整事件迴圈送出 `update_timer` 的 ETA 讀取邏輯，running 期間不重算、paused 期間維持凍結。

## 2. 命令狀態轉換整合

- [x] 2.1 在 command handling（`pause`、`resume`、`reset`）整合 ETA projection 轉換點，避免 reset/resume 漏更新。
- [x] 2.2 驗證初始啟動與 socket 初始投影的 ETA 與新語義一致，避免首包事件與後續事件不一致。

## 3. 測試與回歸防護

- [x] 3.1 擴充 `main/resolveEtaEpochSeconds` 相關測試：running 期間只讀 frozen、paused 凍結、resume/reset 重算。
- [x] 3.2 新增 minute boundary 測試案例，驗證 ETA 不會提早跳分鐘或在邊界來回漂移。
- [x] 3.3 執行 `zig test core/src/main.zig --test-filter "resolveEtaEpochSeconds"` 與必要全檔測試，確認變更未破壞既有行為。
