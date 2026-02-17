## ADDED Requirements

### Requirement: 自動探測 appimagetool 路徑
打包腳本 MUST 按以下優先順序探測 appimagetool：環境變數 `APPIMAGETOOL_BIN` → 專案內 `packaging/tools/appimagetool.AppImage` → PATH 上的 `appimagetool`。

#### Scenario: 未設定環境變數但專案內工具存在
- **WHEN** `APPIMAGETOOL_BIN` 未設定，且 `packaging/tools/appimagetool.AppImage` 存在
- **THEN** 腳本 MUST 自動使用專案內工具完成打包

#### Scenario: 環境變數已設定
- **WHEN** `APPIMAGETOOL_BIN` 已設定為有效路徑
- **THEN** 腳本 MUST 使用環境變數指定的路徑，忽略其他探測

#### Scenario: 所有路徑皆不可用
- **WHEN** 環境變數未設定、專案內工具不存在、PATH 上也找不到
- **THEN** 腳本 MUST 以非零退出碼結束，並輸出錯誤訊息提示下載位置與環境變數設定方式
