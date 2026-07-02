# cli-command-naming Specification

## Purpose
定義系統使用的主要命令名稱，確保所有文檔、打包構件與 CLI 介面保持一致，並避免與系統既有命令發生命名衝突。
## Requirements
### Requirement: 簡潔命令名稱
系統 MUST 以 `ttc` 作為主要命令名稱。所有文檔、打包構件、CLI 幫助文本 MUST 引用 `ttc` 而非 `tic`、`tty-clock-timer` 或 `tty_clock_timer`。AppImage desktop entry 的 `Exec` 欄位 MUST 使用 `ttc`。系統 MUST NOT 提供 `tic` 作為相容 alias。

#### Scenario: 直接執行簡潔命令
- **WHEN** 使用者在終端執行 `ttc --help`
- **THEN** 系統顯示完整 help 文本

#### Scenario: 帶參數執行簡潔命令
- **WHEN** 使用者執行 `ttc --minutes 25`
- **THEN** 系統啟動 25 分鐘倒數計時器

#### Scenario: 文檔中引用簡潔命令
- **WHEN** 查看 README.md 或幫助文本中的示例
- **THEN** 所有示例均使用 `ttc` 作為命令名稱

#### Scenario: AppImage desktop entry 使用簡潔命令
- **WHEN** 檢視 `packaging/appimage/assets/tty-clock-timer.desktop`
- **THEN** `Exec` 欄位 MUST 為 `ttc`
