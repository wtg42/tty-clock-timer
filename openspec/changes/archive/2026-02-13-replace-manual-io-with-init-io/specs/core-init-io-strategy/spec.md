## ADDED Requirements

### Requirement: Core runtime MUST use Init-provided io
core runtime 在 `std.process.Init` 初始化完成後，MUST 使用 `init.io` 作為主要 I/O 來源，且不得再手動建立平行的 `std.Io.Threaded` runtime 實例。

#### Scenario: Main initializes io from Init
- **WHEN** 程式在 `main` 進入執行並完成 `std.process.argsWithAllocator` 及 `std.process.Init` 初始化
- **THEN** I/O 來源 MUST 直接取自 `init.io`，不再額外呼叫手動建構 `std.Io.Threaded`

### Requirement: Observable CLI behavior MUST remain compatible
切換為 `init.io` 後，CLI 的可觀察行為 MUST 與既有語意相容，包括 help/error 輸出與 timer 執行流程。

#### Scenario: No-arg help behavior remains unchanged
- **WHEN** 使用者不提供任何 CLI 參數執行程式
- **THEN** 程式 MUST 顯示既有 help/usage 訊息並正常結束

#### Scenario: Invalid argument error behavior remains unchanged
- **WHEN** 使用者提供無效參數或未知旗標
- **THEN** 程式 MUST 回傳錯誤並輸出既有錯誤語意，不可因 I/O 來源調整而改變錯誤判定邏輯
