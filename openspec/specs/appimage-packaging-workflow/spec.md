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
系統 MUST 能產出可在 Linux x86_64 執行的 AppImage，並通過最小驗收：timer 可運作、key commands 可使用。

#### Scenario: 執行 AppImage 完成 MVP 驗收
- **WHEN** 使用者執行產出的 AppImage
- **THEN** 程式 MUST 啟動 timer 流程並接受關鍵 key commands，以滿足 MVP runnable 定義

### Requirement: 發版流程先採 manual release
系統 MUST 提供手動發版步驟與必要輸出清單，且 MUST 不要求本次變更內建自動化 release pipeline 才能發布。

#### Scenario: 以手動流程完成首次發版
- **WHEN** 維護者依照文件進行 release
- **THEN** 維護者 MUST 可在無 CI 自動化前提下完成 AppImage 產物打包與交付
