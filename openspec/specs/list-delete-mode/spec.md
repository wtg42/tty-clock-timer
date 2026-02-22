# list-delete-mode Specification

## Purpose
TBD - created by archiving change add-list-delete-mode. Update Purpose after archive.
## Requirements
### Requirement: list 子命令支援 --delete 標誌
使用者可以透過 `tty_clock_timer list --delete` 進入刪除模式，使用 gum 的多選介面選擇要刪除的歷史時鐘記錄。

#### Scenario: 使用者執行 list --delete 且有歷史記錄
- **WHEN** 使用者執行 `tty_clock_timer list --delete` 且歷史記錄中有至少一筆紀錄
- **THEN** 系統展示 gum 多選介面，列出所有歷史時鐘時長（格式為 HH:MM (總秒數s)）

#### Scenario: 使用者選擇多項並確認刪除
- **WHEN** 使用者在 gum 多選介面中勾選一個或多個時鐘項目
- **THEN** 系統刪除選中的項目，並將剩餘的歷史記錄輸出到 stdout（同樣的格式）

#### Scenario: 使用者取消選擇（按 Ctrl+C 或無選擇）
- **WHEN** 使用者在 gum 多選介面中按下 Ctrl+C 或未選擇任何項目
- **THEN** 系統輸出「no history」並結束（不進行刪除）

#### Scenario: 使用者刪除所有項目
- **WHEN** 使用者選擇刪除所有的歷史時鐘記錄
- **THEN** 系統刪除所有項目，輸出「no history」並結束

#### Scenario: 無歷史記錄時執行 list --delete
- **WHEN** 使用者執行 `tty_clock_timer list --delete` 但歷史記錄為空
- **THEN** 系統輸出「no history」並結束（不展示選擇介面）

### Requirement: gum 多選工具整合
系統應使用 gum 的多選模式（--no-limit）來允許使用者一次選擇多個項目進行刪除。

#### Scenario: gum 多選輸出
- **WHEN** 使用者在 gum 介面中選擇了多個項目
- **THEN** gum 輸出每行一個選中項目（換行分隔）

#### Scenario: gum 工具不可用時的降級
- **WHEN** gum 工具無法執行（環境不支援或未安裝）
- **THEN** 系統應返回錯誤訊息或使用降級方案（待 design 決定）

### Requirement: 刪除後的歷史記錄輸出
刪除成功後，系統應將剩餘的歷史記錄輸出到 stdout，使用者可以驗證刪除結果。

#### Scenario: 輸出剩餘記錄
- **WHEN** 使用者完成刪除操作
- **THEN** 系統按最後使用時間倒序輸出剩餘的歷史記錄，每條記錄格式為「HH:MM (總秒數s)」

