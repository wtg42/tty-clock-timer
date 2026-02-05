## Context

CLI 目前在啟動時將 stdin 設定為 raw mode（關閉 ICANON/ECHO），並在主迴圈用 poll + streaming reader 讀取輸入。輸入處理集中在 `handleStdinInput`：若緩衝區內沒有換行，只在「單一字元 q」時立即退出；有換行時才用逐行解析與 JSON/keyboard_input 的處理流程。計時結束後仍持續輪詢輸入，但實際行為出現按下 q 無法立即退出的問題。

## Goals / Non-Goals

**Goals:**
- 計時進行中與結束後都能用單鍵 q 立即退出。
- 保留現有 IPC/JSON 解析流程，避免破壞既有輸入格式。
- 行為一致且可預期，不依賴 Enter 或重複輸入。

**Non-Goals:**
- 擴充更多快捷鍵或新的互動流程。
- 重寫 IPC 協定或讓 UI 成為退出決策的主體。
- 大幅調整 TUI 架構或渲染行為。

## Decisions

- **退出決策仍由 core 負責**：UI 只負責顯示，退出鍵統一在 core 處理。替代方案（UI 捕捉鍵盤後透過 IPC 控制退出）需要額外鍵盤事件傳遞與同步，超出本次範圍。
- **新增 raw key 快捷路徑**：當 stdin 是 TTY 且目前緩衝區尚未出現換行時，先檢查是否收到單一字元 q，若是立即退出並只消耗該 byte。其餘情況維持既有逐行解析與 JSON/keyboard_input 行為。這樣可在 raw mode 下保證單鍵退出，同時降低對非互動輸入的誤判。
- **保留行內解析為主流程**：若緩衝區已有換行，依現有邏輯解析完整行並處理 JSON/keyboard_input，避免破壞 IPC 訊息邊界與後續可擴充性。

## Risks / Trade-offs

- **[Risk] raw key 判斷誤觸發於非互動輸入** → Mitigation：僅在 stdin 為 TTY 且無換行時套用 raw key 路徑；其他情況維持逐行解析。
- **[Risk] 讀取與消耗 byte 造成輸入丟失** → Mitigation：只在命中 q 時消耗一個 byte，非 q 則保留緩衝區給既有解析流程處理。

## Migration Plan

- 無資料遷移。變更為 runtime 輸入處理邏輯調整。
- 以手動操作驗證：計時進行中與結束後皆能單鍵 q 退出。
- 若需回退，回復 `handleStdinInput` 的 raw key 判斷邏輯即可。

## Open Questions

- stdin 非 TTY（例如管線輸入）時，是否仍需支援單鍵 q？目前傾向維持行輸入語意。
