## MODIFIED Requirements

### Requirement: Core 與 TUI runtime artifact contract 必須明確
系統 MUST 以文件化規範定義 core 與 TUI runtime 的 artifact contract，至少涵蓋執行入口、必要資產、路徑解析規則與啟動參數介面。TUI artifact 從原始碼目錄結構變更為 bundle 產物結構（JS bundle + `libopentui.so`），入口由 `src/index.tsx` 變更為 bundled JS 檔案。

#### Scenario: 依契約解析 runtime artifact
- **WHEN** core 準備啟動 TUI runtime
- **THEN** core MUST 依 contract 規則定位並載入對應 artifact，而非依賴未定義的隱含路徑

#### Scenario: AppImage 內 AppRun 正確指向 bundle 入口
- **WHEN** AppImage 內的 AppRun 設定 TUI 環境變數
- **THEN** `TTY_CLOCK_TUI_ENTRY` MUST 指向 bundled JS 檔案路徑，`TTY_CLOCK_TUI_CWD` MUST 指向包含 bundle 與 .so 的目錄
