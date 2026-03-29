## MODIFIED Requirements

### Requirement: TUI 顯示倒數時間與狀態
OpenTUI MUST 顯示目前剩餘時間與計時器狀態，且顯示資料 MUST 來自 Node Store/EventBus 的投影狀態；該投影狀態 MUST 由 Zig Core 回傳事件驅動更新。首頁倒數時間主顯示區 MUST 使用 `<ascii_font>` 呈現，且既有控制鍵提示與狀態資訊 MUST 保持可見與可讀。倒數主顯示區 MUST 額外提供 ETA（預計結束時間）輔助資訊，ETA MUST 由 Core 事件提供且格式 MUST 為 `ETA HH:MM`（不顯示秒、不使用 Emoji）。OpenTUI 與 SolidJS dependency upgrade 後，這些既有顯示契約以及完成畫面與命令錯誤訊息 MUST 維持穩定。

#### Scenario: 接收 Core 事件後更新畫面
- **WHEN** Node 收到來自 Zig Core 的 timer 更新事件並同步至 Store
- **THEN** OpenTUI 畫面 MUST 以 `<ascii_font>` 顯示最新剩餘時間，並同時顯示對應狀態

#### Scenario: 命令觸發後狀態反映至畫面
- **WHEN** 使用者在 UI 發送 pause、resume 或 reset 命令且 Core 完成處理
- **THEN** OpenTUI MUST 透過更新後的 Store 投影狀態反映正確 timer 狀態

#### Scenario: 保留既有控制鍵提示與狀態資訊
- **WHEN** 首頁倒數區塊改為 `<ascii_font>` 呈現
- **THEN** 既有控制鍵提示與狀態資訊 MUST 維持顯示，且不因字形切換而遺失

#### Scenario: 執行中顯示 ETA
- **WHEN** timer 狀態為 running 且存在剩餘秒數
- **THEN** 畫面 MUST 顯示來自 Core 事件的 ETA 文案，格式為 `ETA HH:MM`

#### Scenario: 暫停狀態的 ETA 文案
- **WHEN** timer 狀態為 paused
- **THEN** 畫面 MUST 顯示凍結的 `ETA HH:MM`，且該值 MUST NOT 隨時間持續變動

#### Scenario: 重新開始後重算 ETA
- **WHEN** timer 進入新的倒數週期（例如初始開始、resume、或 reset 後重跑）
- **THEN** Core MUST 重新計算 ETA，且畫面 MUST 顯示新的 `ETA HH:MM`

#### Scenario: 完成時顯示完成畫面
- **WHEN** timer 進入 finished 狀態
- **THEN** 畫面 MUST 顯示完成訊息與對應的重新開始或離開提示

#### Scenario: 命令失敗時顯示錯誤訊息
- **WHEN** TUI 命令流程回傳可顯示的錯誤
- **THEN** 畫面 MUST 顯示對應錯誤訊息，且不應覆蓋主要 timer 顯示契約
