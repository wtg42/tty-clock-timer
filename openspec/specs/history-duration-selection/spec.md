# history-duration-selection Specification

## Purpose
TBD - created by archiving change add-history-list-with-gum. Update Purpose after archive.
## Requirements
### Requirement: 系統必須持久化可重用的時長歷史
系統 MUST 在每次成功啟動 timer 後記錄該時長至 history，並將資料儲存在符合 XDG state 規範的路徑。history 記錄 MUST 具備去重與上限控制，避免無限制成長。

#### Scenario: 成功啟動後寫入歷史
- **WHEN** 使用者以任一合法方式啟動 timer（包含參數啟動或 list 選擇）
- **THEN** 系統 MUST 將對應 duration seconds 寫入 history
- **AND** 相同 duration 若已存在 MUST 更新其最近使用時間而非新增重複項目

#### Scenario: 歷史超過上限
- **WHEN** history 筆數超過系統定義上限
- **THEN** 系統 MUST 保留最近使用的紀錄並裁剪較舊項目

### Requirement: 系統必須提供 `list` 子命令供使用者選擇歷史時長
系統 MUST 提供 `tty_clock_timer list` 子命令，列出可用歷史時長並允許使用者選擇；選擇成功後 MUST 直接啟動對應 timer。

#### Scenario: 使用者選擇歷史項目
- **WHEN** 使用者執行 `tty_clock_timer list` 並選取一個歷史時長
- **THEN** 系統 MUST 使用該時長啟動 timer

#### Scenario: 歷史為空
- **WHEN** 使用者執行 `tty_clock_timer list` 但尚無歷史資料
- **THEN** 系統 MUST 顯示可理解的提示並結束 list 流程

#### Scenario: 使用者取消選擇
- **WHEN** 使用者在 list 流程中主動取消
- **THEN** 系統 MUST 結束流程且不得啟動 timer

### Requirement: 系統必須透過 prompt helper 執行互動式 history 流程
系統 MUST 使用 Bun 啟動的 prompt helper 來執行 `list` 與 `list --delete` 的互動流程。系統 MUST NOT 在 prompt helper 缺失、Bun 無法啟動或 helper 執行失敗時自動切換至內建純文字選單。

#### Scenario: prompt helper 無法使用
- **WHEN** core 無法啟動 prompt helper 或 helper 回傳錯誤
- **THEN** 系統 MUST 回報可理解的錯誤訊息
- **AND** 系統 MUST NOT 自動改用純文字 fallback

### Requirement: list 子命令支援 --delete 模式進行多選刪除
使用者可以透過 `tty_clock_timer list --delete` 進入刪除模式，系統 MUST 透過 prompt helper 的多選介面刪除不需要的歷史時長記錄。

#### Scenario: 使用者執行 list --delete 進入多選刪除模式
- **WHEN** 使用者執行 `tty_clock_timer list --delete` 且歷史記錄非空
- **THEN** 系統 MUST 啟動 prompt helper 多選介面，允許使用者選擇一個或多個時長進行刪除

#### Scenario: 使用者選擇多項刪除
- **WHEN** 使用者在多選介面中勾選一個或多個項目
- **THEN** 系統 MUST 刪除選中項目，並將剩餘的歷史記錄輸出到 stdout

#### Scenario: list --delete 時無歷史記錄
- **WHEN** 使用者執行 `tty_clock_timer list --delete` 但歷史記錄為空
- **THEN** 系統 MUST 輸出「no history」並結束

#### Scenario: list --delete 時使用者取消
- **WHEN** 使用者在多選介面中主動取消
- **THEN** 系統 MUST 輸出「no history」並結束（不進行刪除）
