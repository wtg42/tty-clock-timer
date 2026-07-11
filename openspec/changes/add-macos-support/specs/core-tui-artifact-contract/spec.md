## MODIFIED Requirements

### Requirement: Core 與 TUI runtime artifact contract 必須明確
系統 MUST 以文件化規範定義 core 與 TUI runtime 的 artifact contract，至少涵蓋執行入口、必要資產、平台 native library、路徑解析規則與啟動參數介面。TUI artifact MUST 使用 JS bundle、prompt helper、平台對應 OpenTUI native library 與 native package shim；Linux AppImage MUST 使用 `libopentui.so`，macOS arm64 package MUST 使用 `libopentui.dylib`。AppImage 內 core binary contract path MUST 為 `usr/bin/ttc`，且 MUST NOT 提供 `usr/bin/tic` 作為相容 alias；macOS archive MUST 透過 `bin/ttc` launcher 啟動 archive 內的 Zig core。

#### Scenario: 依契約解析 runtime artifact
- **WHEN** core 準備啟動 TUI runtime
- **THEN** core MUST 依 contract 規則定位並載入對應平台 artifact，而非依賴未定義的隱含路徑

#### Scenario: AppImage 內 AppRun 正確指向 bundle 入口
- **WHEN** AppImage 內的 AppRun 設定 TUI 環境變數
- **THEN** `TTY_CLOCK_TUI_ENTRY` MUST 指向 bundled JS 檔案路徑，`TTY_CLOCK_TUI_CWD` MUST 指向包含 bundle 與 `.so` 的目錄

#### Scenario: macOS launcher 正確指向 bundle 入口
- **WHEN** 使用者從任意 working directory 執行 macOS archive 的 `bin/ttc`
- **THEN** launcher MUST 依自身位置設定 `TTY_CLOCK_TUI_ENTRY` 與 `TTY_CLOCK_TUI_CWD`
- **AND** runtime cwd MUST 包含 bundle、prompt helper、Darwin arm64 shim 與 `.dylib`

### Requirement: Core 保持 UI 啟動責任
系統 MUST 維持 core 為 UI 啟動與生命週期管理的唯一責任方，Linux AppImage 或 macOS package 的 launcher 均不得取代該控制流程。

#### Scenario: AppImage 內啟動 UI
- **WHEN** 使用者執行 AppImage
- **THEN** UI MUST 由 core 啟動並受 core 生命週期控制，且不應由外部包裝腳本直接接管 UI 主流程

#### Scenario: macOS package 內啟動 UI
- **WHEN** 使用者執行 macOS archive 的 launcher
- **THEN** launcher MUST `exec` Zig core，且 UI MUST 由 core 建立、管理與回收

### Requirement: Contract 需支援可驗證的最小兼容檢查
系統 MUST 定義可自動或人工驗證的 contract 檢查項目，至少包含 artifact 存在性、平台 native library 與 shim 一致性、入口可啟動性、必要參數一致性，以及 core–TUI socket smoke test。

#### Scenario: 進行 AppImage release 前檢查
- **WHEN** 維護者準備發佈 AppImage
- **THEN** 維護者 MUST 可依 contract 清單逐項驗證 core 與 TUI runtime 的整合兼容性

#### Scenario: 進行 macOS release 前檢查
- **WHEN** 維護者準備發佈 macOS arm64 archive
- **THEN** package verification MUST 檢查所有必要 artifacts、Darwin native library 載入與 core–TUI socket 啟動流程

