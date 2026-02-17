# appimage-packaging-workflow Specification

## Purpose
TBD - created by archiving change appimage-packaging-foundation. Update Purpose after archive.

## Requirements

### Requirement: Linux x86_64 AppImage 打包骨架
系統 MUST 提供 `packaging/appimage` 目錄骨架，並定義 Linux x86_64 的打包輸入、輸出與執行步驟，作為後續發版流程的單一來源。

#### Scenario: 建立標準打包骨架
- **WHEN** 開發者初始化 AppImage 打包流程
- **THEN** 專案 MUST 存在可辨識的 `packaging/appimage` 結構與必要說明，且明確標示目標平台為 Linux x86_64

### Requirement: MVP AppImage 產物可直接執行
系統 MUST 能產出可在 Linux x86_64 執行的 AppImage，並通過最小驗收：timer 可運作、key commands 可使用。打包腳本 MUST 使用 TUI build 產物（bundle + native .so）而非原始碼目錄，以避免將 `node_modules` 打入 AppImage。

#### Scenario: 執行 AppImage 完成 MVP 驗收
- **WHEN** 使用者執行產出的 AppImage
- **THEN** 程式 MUST 啟動 timer 流程並接受關鍵 key commands，以滿足 MVP runnable 定義

#### Scenario: AppImage 不包含 node_modules
- **WHEN** 檢視 AppImage 內的 TUI 檔案結構
- **THEN** MUST 不存在 `node_modules` 目錄，TUI 部分僅包含 JS bundle 與 native .so

### Requirement: 發版流程先採 manual release
系統 MUST 提供手動發版步驟與必要輸出清單，且 MUST 不要求本次變更內建自動化 release pipeline 才能發布。系統 MAY 提供以 tag-driven workflow 執行的自動化 release 路徑，但該路徑 MUST 與 manual release 共存，且在自動化不可用時維護者仍 MUST 可透過 manual release 完成交付。打包腳本 MUST 自動探測 appimagetool 路徑，使用者無需手動設定 `APPIMAGETOOL_BIN` 即可完成打包。

#### Scenario: 以手動流程完成首次發版
- **WHEN** 維護者依照文件進行 release
- **THEN** 維護者 MUST 可在無 CI 自動化前提下完成 AppImage 產物打包與交付

#### Scenario: 無需手動設定環境變數即可打包
- **WHEN** 維護者在專案內已有 `packaging/tools/appimagetool.AppImage` 的環境下執行打包腳本
- **THEN** 腳本 MUST 自動探測工具路徑，無需預先設定 `APPIMAGETOOL_BIN`

#### Scenario: 自動化路徑不可用時可退回 manual release
- **WHEN** tag-driven release workflow 因 CI 或環境因素失敗
- **THEN** 維護者 MUST 仍可依既有 manual release 流程完成同版本 AppImage 交付
