## MODIFIED Requirements

### Requirement: Socket 生命週期需可恢復
系統 MUST 在 socket 初始化與重啟流程中處理殘留 socket 檔案與連線失敗，並提供可診斷錯誤訊息。系統在每次啟動時 MUST 產生執行實例唯一的 socket path（例如包含 PID、隨機後綴或等效唯一機制），以避免多實例衝突並適用 AppImage 執行環境。

#### Scenario: 啟動時存在殘留 socket 檔案
- **WHEN** 進程啟動時發現目標 socket path 已存在且無有效連線
- **THEN** 系統 MUST 執行安全清理或明確報錯，避免無聲失敗

#### Scenario: 同時啟動多個 AppImage 實例
- **WHEN** 同一使用者同時啟動兩個以上程式實例
- **THEN** 每個實例 MUST 使用不同 socket path，且彼此不應因 path 衝突而導致 IPC 初始化失敗
