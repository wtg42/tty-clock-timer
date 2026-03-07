## ADDED Requirements

### Requirement: Core 必須可透過 Bun 啟動 prompt helper artifact
系統 MUST 提供可由 Bun 直接執行的 prompt helper bundle，預設相對於 TUI runtime root 的路徑為 `prompts/helper.js`。Zig core MUST 以子命令方式呼叫此 helper，供 history 單選、history 多選刪除與 sound setup 互動流程共用。

#### Scenario: Core 解析並啟動 helper
- **WHEN** core 需要啟動 history 或 sound setup prompt flow
- **THEN** core MUST 以 `bun run <helper-entry> -- <subcommand>` 形式啟動 prompt helper
- **AND** `<helper-entry>` MUST 解析到 TUI runtime root 下的 `prompts/helper.js`

### Requirement: Prompt helper 必須以 JSON 回傳互動結果
prompt helper MUST 以單一 JSON 物件作為 stdout 回應，並使用固定 `status` 欄位表達 `submitted`、`canceled` 或 `error`。不同子命令的成功 payload MUST 提供欄位化資料，避免 Zig 端依賴純文字解析。

#### Scenario: 單選 history 成功
- **WHEN** 使用者完成 history 單選
- **THEN** helper MUST 輸出 `{"status":"submitted","duration_seconds":<number>}`

#### Scenario: 多選刪除成功
- **WHEN** 使用者完成 history 多選刪除
- **THEN** helper MUST 輸出 `{"status":"submitted","selected_labels":[... ]}`

#### Scenario: 使用者取消互動
- **WHEN** 使用者在任一 prompt flow 中主動取消
- **THEN** helper MUST 輸出 `{"status":"canceled"}`

### Requirement: Prompt helper 失敗時必須提供可辨識錯誤結果
當 helper 遇到無法完成的預期錯誤（例如輸入資料不合法、所需參數缺失或 Bun prompt 啟動失敗）時，helper MUST 回傳 JSON 錯誤結果並以非零退出碼結束，讓 Zig core 能輸出可理解的錯誤訊息。

#### Scenario: helper 回傳預期錯誤
- **WHEN** helper 無法完成指定 prompt flow
- **THEN** helper MUST 輸出 `{"status":"error","code":"<error-code>"}`
- **AND** helper MUST 以非零退出碼結束
