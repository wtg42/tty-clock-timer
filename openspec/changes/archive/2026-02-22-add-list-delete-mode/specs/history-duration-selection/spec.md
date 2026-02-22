## ADDED Requirements

### Requirement: list 子命令支援 --delete 模式進行多選刪除
使用者可以透過 `tty_clock_timer list --delete` 進入刪除模式，使用 gum 多選介面刪除不需要的歷史時長記錄。

#### Scenario: 使用者執行 list --delete 進入多選刪除模式
- **WHEN** 使用者執行 `tty_clock_timer list --delete` 且歷史記錄非空
- **THEN** 系統展示 gum 多選介面，允許使用者選擇一個或多個時長進行刪除

#### Scenario: 使用者選擇多項刪除
- **WHEN** 使用者在多選介面中勾選一個或多個項目
- **THEN** 系統 MUST 刪除選中項目，並將剩餘的歷史記錄輸出到 stdout

#### Scenario: list --delete 時無歷史記錄
- **WHEN** 使用者執行 `tty_clock_timer list --delete` 但歷史記錄為空
- **THEN** 系統 MUST 輸出「no history」並結束

#### Scenario: list --delete 時使用者取消
- **WHEN** 使用者在多選介面中按 Ctrl+C 或未作選擇
- **THEN** 系統 MUST 輸出「no history」並結束（不進行刪除）
