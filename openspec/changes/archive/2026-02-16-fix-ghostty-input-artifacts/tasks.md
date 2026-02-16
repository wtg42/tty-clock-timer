## 1. 輸入事件來源重構

- [x] 1.1 在 TUI 改用 OpenTUI 鍵盤事件 API 取代 `process.stdin.on("data")` 字元流解析
- [x] 1.2 只映射合法控制鍵（`p/r/s/q`）到 command，移除原始位元組逐字判斷路徑
- [x] 1.3 加入 press/repeat 區分邏輯，避免非預期重複事件直接觸發命令

## 2. 命令降噪與狀態保護

- [x] 2.1 在 command dispatch 層加入同命令短時間重複抑制機制
- [x] 2.2 針對 `pause/resume` 加入狀態前置檢查，減少可預期 `invalid_state`
- [x] 2.3 調整錯誤顯示策略，避免連續錯誤覆寫導致畫面可讀性下降

## 3. 退出流程與 terminal cleanup

- [x] 3.1 TUI `quit` 路徑改為 graceful teardown（先清理 renderer/socket，再退出）
- [x] 3.2 Core 子程序管理改為先等待正常結束，逾時才 fallback 強制終止
- [x] 3.3 確認 raw mode/terminal state 在所有主要退出路徑都會還原

## 4. 驗證與回歸

- [x] 4.1 新增手動驗證清單：Ghostty 非 tmux 下「不按鍵 10 秒無 `invalid_state`」
- [x] 4.2 新增手動驗證清單：長按 `p` 不造成錯誤洗版或重疊
- [x] 4.3 新增手動驗證清單：tmux 與非 tmux 退出後都可正常選字
- [x] 4.4 執行既有 core 測試（`zig build test`）並記錄結果
