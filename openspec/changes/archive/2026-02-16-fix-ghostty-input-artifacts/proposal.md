## Why

在非 tmux（例如 Ghostty）環境下，倒數 UI 會在未按鍵情況下出現 `invalid_state`，並伴隨文字重疊與退出後終端狀態殘留（無法正常選取文字）。這代表目前的輸入事件來源與終端清理流程存在穩定性缺口，需要優先修補以確保不同 terminal 環境的一致行為。

## What Changes

- 將 TUI 指令觸發來源從原始 `stdin` 字元流改為可辨識的鍵盤事件模型，避免把 terminal 控制序列誤判為 `p/r/s/q` 指令。
- 增加命令送出保護（去重/節流或狀態前置檢查），降低重複命令造成 `invalid_state` 的噪音。
- 調整 Core 與 TUI 退出路徑為 graceful teardown，避免直接中止造成 terminal mode 未還原。
- 定義跨 terminal（tmux、Ghostty）可驗證的行為基準，確保無輸入時不會自動觸發 command error。

## Capabilities

### New Capabilities
- `terminal-input-hygiene`: 確保 TUI 只處理真實鍵盤事件，不將控制序列誤判為指令。
- `terminal-state-cleanup`: 確保程序退出後 terminal 狀態完整還原（可正常選字與互動）。

### Modified Capabilities
- `hono-command-plane`: 補強命令請求/回應在重複輸入與非預期輸入下的錯誤語意與降噪策略。
- `quit-on-q`: 調整退出時序與清理責任，確保 Core/TUI 終止流程一致且可恢復終端狀態。

## Impact

- `tui/src/index.tsx`：鍵盤輸入來源與 command dispatch 流程。
- `tui/src/unix_socket_adapter.ts`、`tui/src/command_plane.ts`：命令送出與錯誤處理策略。
- `core/src/main.zig`：子程序終止與 TTY/raw mode 清理時機。
- 測試與驗證流程：需新增 tmux 與非 tmux（Ghostty）場景的手動驗證步驟。
