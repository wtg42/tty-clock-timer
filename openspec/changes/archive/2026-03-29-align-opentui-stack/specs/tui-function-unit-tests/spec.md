## MODIFIED Requirements

### Requirement: Deterministic local execution
系統 SHALL 提供可重複執行的本機測試入口，使開發者可用單一命令、指定檔案或測試 filter 穩定重現 function-level unit test 結果，並在 dependency upgrade 流程中與 renderer-based integration tests 分層執行回歸檢查。

#### Scenario: 本機重複執行結果一致
- **WHEN** 開發者在相同程式碼版本重複執行 unit test 命令
- **THEN** 測試結果可被穩定重現，且失敗案例可對應到特定函式邏輯

#### Scenario: 單獨執行 function-level tests
- **WHEN** 維護者使用指定檔案或測試 filter 僅執行 function-level unit tests
- **THEN** 系統 SHALL 能在不啟動 renderer-based integration tests 的情況下穩定完成測試
