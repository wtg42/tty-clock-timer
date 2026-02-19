## MODIFIED Requirements

### Requirement: 發版流程先採 manual release
系統 MUST 提供手動發版步驟與必要輸出清單，且 MUST 不要求本次變更內建自動化 release pipeline 才能發布。系統 MAY 提供以 tag-driven workflow 執行的自動化 release 路徑，但該路徑 MUST 與 manual release 共存，且在自動化不可用時維護者仍 MUST 可透過 manual release 完成交付。打包腳本 MUST 自動探測 appimagetool 路徑，使用者無需手動設定 `APPIMAGETOOL_BIN` 即可完成打包。打包腳本 MUST 在每次打包前清除專案內 build 產物並強制重建 core 與 TUI，以避免沿用舊的 stage binary；清理範圍 MUST 限制在專案目錄內，不得要求清除全域 cache。

#### Scenario: 以手動流程完成首次發版
- **WHEN** 維護者依照文件進行 release
- **THEN** 維護者 MUST 可在無 CI 自動化前提下完成 AppImage 產物打包與交付

#### Scenario: 無需手動設定環境變數即可打包
- **WHEN** 維護者在專案內已有 `packaging/tools/appimagetool.AppImage` 的環境下執行打包腳本
- **THEN** 腳本 MUST 自動探測工具路徑，無需預先設定 `APPIMAGETOOL_BIN`

#### Scenario: 自動化路徑不可用時可退回 manual release
- **WHEN** tag-driven release workflow 因 CI 或環境因素失敗
- **THEN** 維護者 MUST 仍可依既有 manual release 流程完成同版本 AppImage 交付

#### Scenario: 每次打包都重建並避免沿用舊 stage binary
- **WHEN** 維護者在同一個專案工作樹內重複執行打包腳本
- **THEN** 腳本 MUST 先清理專案內 build 產物並重建 core 與 TUI，再產生 AppImage，且不得依賴既有 `stage/usr/bin/tty_clock_timer`

#### Scenario: 清理不影響全域開發環境
- **WHEN** 腳本執行 clean rebuild
- **THEN** 清理操作 MUST 僅作用於專案內建置產物路徑，且 MUST NOT 清除全域 cache 或其他專案資料
