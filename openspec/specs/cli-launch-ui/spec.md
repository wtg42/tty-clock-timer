# cli-launch-ui Specification

## Purpose
TBD - created by archiving change cli-launches-ui. Update Purpose after archive.

## Requirements

### Requirement: CLI 啟動時自動啟動 UI
CLI MUST 在成功啟動計時器後啟動 OpenTUI UI 進程，並建立 IPC 管道以傳遞 timer 更新訊息；並且 MUST 能在不同工作目錄下正確定位 UI 目錄。

#### Scenario: 正常啟動 UI
- **WHEN** 使用者透過 CLI 啟動計時器
- **THEN** 系統啟動 UI 進程並開始接收 timer 更新訊息

#### Scenario: 從 core 目錄啟動 UI
- **WHEN** 使用者在 `core/` 目錄執行 CLI 且專案根目錄存在 `tui/`
- **THEN** 系統仍能找到 UI 目錄並啟動 UI 進程

#### Scenario: UI 目錄不存在
- **WHEN** CLI 啟動時無法在預期路徑找到 UI 目錄
- **THEN** 系統輸出錯誤訊息並包含目前工作目錄與已嘗試路徑
