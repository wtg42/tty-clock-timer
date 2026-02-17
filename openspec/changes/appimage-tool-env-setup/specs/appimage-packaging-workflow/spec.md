## MODIFIED Requirements

### Requirement: 發版流程先採 manual release
系統 MUST 提供手動發版步驟與必要輸出清單，且 MUST 不要求本次變更內建自動化 release pipeline 才能發布。打包腳本 MUST 自動探測 appimagetool 路徑，使用者無需手動設定 `APPIMAGETOOL_BIN` 即可完成打包。

#### Scenario: 以手動流程完成首次發版
- **WHEN** 維護者依照文件進行 release
- **THEN** 維護者 MUST 可在無 CI 自動化前提下完成 AppImage 產物打包與交付

#### Scenario: 無需手動設定環境變數即可打包
- **WHEN** 維護者在專案內已有 `packaging/tools/appimagetool.AppImage` 的環境下執行打包腳本
- **THEN** 腳本 MUST 自動探測工具路徑，無需預先設定 `APPIMAGETOOL_BIN`
