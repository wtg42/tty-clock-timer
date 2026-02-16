## Context

目前 TUI 以 `process.stdin.on("data")` 逐字元解析輸入，任何包含 `p/r/s/q` 的輸入片段都可能被映射成命令。這在非 tmux 終端（例如 Ghostty）更容易遇到：terminal 協商/控制序列可能混入 stdin，造成未按鍵仍觸發 command，並收到 `invalid_state`。同時，Core 與 TUI 的退出流程包含直接 `process.exit` 與 child kill 路徑，可能使 renderer 無法完成 terminal 還原，導致程式退出後無法正常選取文字。

## Goals / Non-Goals

**Goals:**
- 讓命令來源只來自「可辨識的鍵盤事件」，避免 raw stdin 污染導致誤觸發。
- 在長按或重複事件情境下，降低 `invalid_state` 對 UI 的噪音。
- 建立一致的 graceful teardown，確保退出後 terminal 狀態可恢復（可選字、可正常輸入）。
- 保持現有 `p/r/s/q` 鍵位與 IPC 協定相容。

**Non-Goals:**
- 不改動 timer 核心狀態機語意（running/paused/finished 規則不變）。
- 不新增新的使用者命令集合（例如 add-time、lap）。
- 不重寫 IPC transport（仍使用 Unix socket + JSON lines）。

## Decisions

1. 使用 OpenTUI 鍵盤事件 API 取代 raw stdin 逐字元解析
- 決策：在 TUI 層改為 `useKeyboard`/renderer keyboard 事件來源，只處理 `eventType` 可識別且 `name` 屬於 `p/r/s/q` 的輸入。
- 理由：可直接區分 press/repeat/release，並隔離 terminal 控制序列，不再把非使用者輸入當命令。
- 替代方案：維持 `stdin.on("data")` 並手寫 escape sequence 過濾。未採用，因為終端差異大且維護成本高。

2. 命令發送加入最小保護（去重或狀態前置檢查）
- 決策：對同一命令在短時間重複觸發時做抑制，且僅在合理狀態送出（例如 paused 才送 resume）。
- 理由：避免長按造成大量可預期失敗，降低 UI 噪音與狀態抖動。
- 替代方案：完全依賴 Core 回 `invalid_state`。未採用，因為雖可正確但體驗噪音高。

3. 退出流程改為先協調、後回收的 graceful teardown
- 決策：TUI 優先走 renderer 正常銷毀與 socket 關閉；Core 先送 exit/等待子程序收尾，再使用 timeout fallback（必要時才強制中止）。
- 理由：確保 terminal mode（含滑鼠/alternate screen/輸入模式）由 renderer 完整回復。
- 替代方案：維持立即 `process.exit` / `child.kill`。未採用，因為已觀測到終端狀態殘留。

4. 驗證策略以環境矩陣為準
- 決策：至少覆蓋 tmux 與非 tmux（Ghostty）兩種環境，驗證「無按鍵不出現 command error」與「退出後可選字」。
- 理由：此問題具明顯環境依賴，單一路徑測試不足以覆蓋風險。

## Risks / Trade-offs

- [風險] 鍵盤事件 API 在不同終端仍有行為差異 → [緩解] 以 press/repeat 分流設計，並在 Ghostty/tmux 都做驗證。
- [風險] 去重策略過嚴可能吞掉使用者預期輸入 → [緩解] 只抑制明顯重複且不合法的命令，保留狀態切換後的下一次有效輸入。
- [風險] graceful teardown 增加退出路徑複雜度 → [緩解] 設定明確 timeout 與 fallback，避免程序卡住。
- [取捨] 增加一些前端狀態判斷邏輯，換取跨 terminal 的穩定與可預期 UX。
