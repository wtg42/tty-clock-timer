# core-tui-artifact-contract Specification

## Purpose
TBD - created by archiving change appimage-packaging-foundation. Update Purpose after archive.

## Requirements

### Requirement: Core 與 TUI runtime artifact contract 必須明確
系統 MUST 以文件化規範定義 core 與 TUI runtime 的 artifact contract，至少涵蓋執行入口、必要資產、路徑解析規則與啟動參數介面。TUI artifact 從原始碼目錄結構變更為 bundle 產物結構（JS bundle + `libopentui.so`），入口由 `src/index.tsx` 變更為 bundled JS 檔案。

#### Scenario: 依契約解析 runtime artifact
- **WHEN** core 準備啟動 TUI runtime
- **THEN** core MUST 依 contract 規則定位並載入對應 artifact，而非依賴未定義的隱含路徑

#### Scenario: AppImage 內 AppRun 正確指向 bundle 入口
- **WHEN** AppImage 內的 AppRun 設定 TUI 環境變數
- **THEN** `TTY_CLOCK_TUI_ENTRY` MUST 指向 bundled JS 檔案路徑，`TTY_CLOCK_TUI_CWD` MUST 指向包含 bundle 與 .so 的目錄

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

### Requirement: Core 與 TUI 的 IPC update_timer 訊息格式
Core 發送 `update_timer` IPC 訊息時，ETA 欄位 MUST 使用 `eta_epoch_seconds`（Unix timestamp，單位：秒，型別：`number`）。`eta_hhmm` 欄位 MUST NOT 出現於訊息中。TUI 端 MUST 將 `eta_epoch_seconds` 轉換為本地時間的 `HH:MM` 格式後顯示給使用者。

#### Scenario: Core 傳送 update_timer 訊息
- **WHEN** 計時器狀態更新並觸發 IPC 通知
- **THEN** Core MUST 在 `update_timer` payload 中包含 `eta_epoch_seconds` 數值欄位，且 MUST NOT 包含 `eta_hhmm` 字串欄位

#### Scenario: TUI 顯示 ETA 本地時間
- **WHEN** TUI 收到含 `eta_epoch_seconds` 的 `update_timer` 訊息
- **THEN** TUI MUST 將其轉換為系統本地時區的 `HH:MM` 格式並顯示，而非 UTC 時間
