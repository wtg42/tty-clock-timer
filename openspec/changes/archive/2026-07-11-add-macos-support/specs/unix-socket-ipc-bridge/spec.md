## MODIFIED Requirements

### Requirement: Socket 生命週期需可恢復
系統 MUST 在 socket 初始化與重啟流程中處理殘留 socket 檔案與連線失敗，並提供可診斷錯誤訊息。系統在每次啟動時 MUST 產生執行實例唯一的 socket path（例如包含 PID、隨機後綴或等效唯一機制），以避免多實例衝突並適用 Linux AppImage 與 macOS 執行環境。系統 MUST 優先嘗試非空且可用的 `TMPDIR`，再 fallback 至 `/tmp`；完整 path MUST 符合平台 Unix Domain Socket 長度限制，且候選過長或不可用時 MUST 嘗試下一候選，而非直接使用無效 path。

#### Scenario: 啟動時存在殘留 socket 檔案
- **WHEN** 進程啟動時發現目標 socket path 已存在且無有效連線
- **THEN** 系統 MUST 執行安全清理或明確報錯，避免無聲失敗

#### Scenario: 同時啟動多個 packaged 實例
- **WHEN** 同一使用者同時啟動兩個以上 Linux AppImage 或 macOS package 實例
- **THEN** 每個實例 MUST 使用不同 socket path，且彼此不應因 path 衝突而導致 IPC 初始化失敗

#### Scenario: macOS TMPDIR 可用且路徑合法
- **WHEN** `TMPDIR` 非空、可使用，且組合後的 socket path 符合平台長度限制
- **THEN** core MUST 在該目錄建立唯一 socket 並於結束時清理

#### Scenario: TMPDIR socket path 過長
- **WHEN** `TMPDIR` 與唯一檔名組合後超出 Unix Domain Socket path 長度限制
- **THEN** core MUST 改以 `/tmp` 產生合法的唯一 socket path
- **AND** core MUST NOT 因第一候選過長而直接終止

