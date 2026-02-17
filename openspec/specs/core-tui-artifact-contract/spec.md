# core-tui-artifact-contract Specification

## Purpose
TBD - created by archiving change appimage-packaging-foundation. Update Purpose after archive.

## Requirements

### Requirement: Core 與 TUI runtime artifact contract 必須明確
系統 MUST 以文件化規範定義 core 與 TUI runtime 的 artifact contract，至少涵蓋執行入口、必要資產、路徑解析規則與啟動參數介面。

#### Scenario: 依契約解析 runtime artifact
- **WHEN** core 準備啟動 TUI runtime
- **THEN** core MUST 依 contract 規則定位並載入對應 artifact，而非依賴未定義的隱含路徑

### Requirement: Core 保持 UI 啟動責任
系統 MUST 維持 core 為 UI 啟動與生命週期管理的唯一責任方，打包層不得取代該控制流程。

#### Scenario: AppImage 內啟動 UI
- **WHEN** 使用者執行 AppImage
- **THEN** UI MUST 由 core 啟動並受 core 生命週期控制，且不應由外部包裝腳本直接接管 UI 主流程

### Requirement: Contract 需支援可驗證的最小兼容檢查
系統 MUST 定義可人工驗證的 contract 檢查項目，至少包含 artifact 存在性、入口可啟動性與必要參數一致性。

#### Scenario: 進行手動 release 前檢查
- **WHEN** 維護者準備發佈 AppImage
- **THEN** 維護者 MUST 可依 contract 清單逐項驗證 core 與 TUI runtime 的整合兼容性
