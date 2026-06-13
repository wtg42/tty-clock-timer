## MODIFIED Requirements

### Requirement: Integration tests MUST 覆蓋升級敏感的 UI 契約
integration tests MUST 至少覆蓋倒數畫面、完成畫面、錯誤訊息與 keyboard interaction 等升級敏感的 UI 契約，避免 OpenTUI 或 SolidJS 升級後發生未被偵測的行為漂移。OpenTUI dependency bump 前後 MUST 使用同一批 renderer-based tests 驗證契約仍成立。

#### Scenario: 驗證完成畫面契約
- **WHEN** TUI 狀態投影為已完成
- **THEN** integration test MUST 驗證完成畫面仍顯示預期的完成訊息與重新開始/離開提示

#### Scenario: 驗證 keyboard interaction 契約
- **WHEN** integration test 模擬符合支援範圍的按鍵事件
- **THEN** TUI MUST 觸發對應命令流程或狀態更新，且不依賴人工手動驗證

#### Scenario: OpenTUI 升級前後契約一致
- **WHEN** OpenTUI dependency bump 前後執行 renderer integration tests
- **THEN** 倒數畫面、完成畫面、錯誤訊息與 keyboard interaction 的使用者可見契約 MUST 維持一致
