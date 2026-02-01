## ADDED Requirements

### Requirement: CLI 啟動時自動啟動 UI
CLI MUST 在成功啟動計時器後啟動 OpenTUI UI 進程，並建立 IPC 管道以傳遞 timer 更新訊息。

#### Scenario: 正常啟動 UI
- **WHEN** 使用者透過 CLI 啟動計時器
- **THEN** 系統啟動 UI 進程並開始接收 timer 更新訊息
