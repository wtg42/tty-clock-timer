## MODIFIED Requirements

### Requirement: 系統必須提供 `list` 子命令供使用者選擇歷史時長
系統 MUST 提供 `ttc list` 子命令，列出可用歷史時長並允許使用者選擇；選擇成功後 MUST 直接啟動對應 timer。

#### Scenario: 使用者選擇歷史項目
- **WHEN** 使用者執行 `ttc list` 並選取一個歷史時長
- **THEN** 系統 MUST 使用該時長啟動 timer

#### Scenario: 歷史為空
- **WHEN** 使用者執行 `ttc list` 但尚無歷史資料
- **THEN** 系統 MUST 顯示可理解的提示並結束 list 流程

#### Scenario: 使用者取消選擇
- **WHEN** 使用者在 list 流程中主動取消
- **THEN** 系統 MUST 結束流程且不得啟動 timer

### Requirement: list 子命令支援 --delete 模式進行多選刪除
使用者可以透過 `ttc list --delete` 進入刪除模式，系統 MUST 透過 prompt helper 的多選介面刪除不需要的歷史時長記錄。

#### Scenario: 使用者執行 list --delete 進入多選刪除模式
- **WHEN** 使用者執行 `ttc list --delete` 且歷史記錄非空
- **THEN** 系統 MUST 啟動 prompt helper 多選介面，允許使用者選擇一個或多個時長進行刪除

#### Scenario: 使用者選擇多項刪除
- **WHEN** 使用者在多選介面中勾選一個或多個項目
- **THEN** 系統 MUST 刪除選中項目，並將剩餘的歷史記錄輸出到 stdout

#### Scenario: list --delete 時無歷史記錄
- **WHEN** 使用者執行 `ttc list --delete` 但歷史記錄為空
- **THEN** 系統 MUST 輸出「no history」並結束

#### Scenario: list --delete 時使用者取消
- **WHEN** 使用者在多選介面中主動取消
- **THEN** 系統 MUST 輸出「no history」並結束（不進行刪除）
