## MODIFIED Requirements

### Requirement: 無參數啟動時顯示完整 CLI 說明
系統在未提供任何參數啟動 CLI 時 MUST 顯示完整 help 說明，且該內容 MUST 與 `--help` 旗標輸出一致。

#### Scenario: 無參數直接啟動
- **WHEN** 使用者執行 `ttc` 且未提供任何參數
- **THEN** 系統顯示完整 Usage、Options、Example 區塊
- **AND** 顯示內容與 `ttc --help` 相同

### Requirement: 無參數情境視為說明流程
系統在無參數情境 MUST 走說明流程而非錯誤流程，避免輸出「缺少參數」錯誤文案。

#### Scenario: 無參數不顯示錯誤訊息
- **WHEN** 使用者在無參數情境啟動 CLI
- **THEN** 輸出中不包含「Missing arguments」或同義錯誤訊息
- **AND** 流程以 help 行為結束

### Requirement: 其他參數錯誤仍保留錯誤語意
系統對於未知旗標、缺少值或非數字等輸入錯誤 MUST 維持錯誤語意與錯誤訊息，不得因無參數友善化而放寬。

#### Scenario: 提供未知旗標
- **WHEN** 使用者執行 `ttc --unknown`
- **THEN** 系統回報未知參數錯誤訊息

#### Scenario: 提供秒數旗標但缺值
- **WHEN** 使用者執行 `ttc --seconds`
- **THEN** 系統回報缺少秒數值錯誤訊息

#### Scenario: 提供非數字值
- **WHEN** 使用者執行 `ttc --minutes abc`
- **THEN** 系統回報無效數字錯誤訊息
