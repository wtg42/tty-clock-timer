## MODIFIED Requirements

### Requirement: 升級後必須完成最小驗證
每次 OpenTUI 或 lockfile 管理策略變更後，開發流程 SHALL 執行最小驗證以確保可建置、可測試，且終端互動行為無回歸。

#### Scenario: 依賴更新完成後執行自動化驗證
- **WHEN** OpenTUI 版本或 lockfile 發生變更
- **THEN** MUST 成功執行 `bun install`、`bun run build`、`bun test`

#### Scenario: 依賴更新完成後執行終端互動回歸驗證
- **WHEN** OpenTUI 版本升級完成且自動化驗證已通過
- **THEN** MUST 驗證 focus/blur 切換、退出後 terminal state 還原、鍵盤控制（`p/r/s/q`）與倒數/完成畫面渲染完整性皆維持正確行為
