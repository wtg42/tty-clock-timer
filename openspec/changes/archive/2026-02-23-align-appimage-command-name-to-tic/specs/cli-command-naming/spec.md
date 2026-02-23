## MODIFIED Requirements

### Requirement: 簡潔命令名稱
系統 MUST 以 `tic` 作為主要命令名稱。所有文檔、打包構件、CLI 幫助文本 MUST 引用 `tic` 而非 `tty-clock-timer` 或 `tty_clock_timer`。AppImage desktop entry 的 `Exec` 欄位 MUST 使用 `tic`。

#### Scenario: 直接執行簡潔命令
- **WHEN** 使用者在終端執行 `tic --help`
- **THEN** 系統顯示完整 help 文本

#### Scenario: 帶參數執行簡潔命令
- **WHEN** 使用者執行 `tic --minutes 25`
- **THEN** 系統啟動 25 分鐘倒數計時器

#### Scenario: 文檔中引用簡潔命令
- **WHEN** 查看 README.md 或幫助文本中的示例
- **THEN** 所有示例均使用 `tic` 作為命令名稱

#### Scenario: AppImage desktop entry 使用簡潔命令
- **WHEN** 檢視 `packaging/appimage/assets/tty-clock-timer.desktop`
- **THEN** `Exec` 欄位 MUST 為 `tic`
