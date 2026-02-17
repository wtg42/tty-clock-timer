## MODIFIED Requirements

### Requirement: MVP AppImage 產物可直接執行
系統 MUST 能產出可在 Linux x86_64 執行的 AppImage，並通過最小驗收：timer 可運作、key commands 可使用。打包腳本 MUST 使用 TUI build 產物（bundle + native .so）而非原始碼目錄，以避免將 `node_modules` 打入 AppImage。

#### Scenario: 執行 AppImage 完成 MVP 驗收
- **WHEN** 使用者執行產出的 AppImage
- **THEN** 程式 MUST 啟動 timer 流程並接受關鍵 key commands，以滿足 MVP runnable 定義

#### Scenario: AppImage 不包含 node_modules
- **WHEN** 檢視 AppImage 內的 TUI 檔案結構
- **THEN** MUST 不存在 `node_modules` 目錄，TUI 部分僅包含 JS bundle 與 native .so
