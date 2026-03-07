## ADDED Requirements

### Requirement: 系統必須透過 prompt helper 執行互動式 history 流程
系統 MUST 使用 Bun 啟動的 prompt helper 來執行 `list` 與 `list --delete` 的互動流程。系統 MUST NOT 在 prompt helper 缺失、Bun 無法啟動或 helper 執行失敗時自動切換至內建純文字選單。

#### Scenario: prompt helper 無法使用
- **WHEN** core 無法啟動 prompt helper 或 helper 回傳錯誤
- **THEN** 系統 MUST 回報可理解的錯誤訊息
- **AND** 系統 MUST NOT 自動改用純文字 fallback

## REMOVED Requirements

### Requirement: 系統必須以 `gum` 優化互動並提供 fallback
**Reason**: CLI prompt flow 改由 Bun + Clack helper 統一處理，不再維護 `gum` 與純 Zig fallback 的雙路徑。
**Migration**: `list` 流程改依賴 prompt helper；若 helper 無法啟動，系統直接回報錯誤並結束。

## MODIFIED Requirements

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
