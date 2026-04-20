## MODIFIED Requirements

### Requirement: OpenTUI 套件版本需維持最新穩定版
`@opentui/core` 與 `@opentui/solid` 在升級工作中 SHALL 更新至當下最新穩定版本，以降低未來跨多版跳升級風險。兩者在同一次升級中 MUST 對齊為同一批相容版本，且 lockfile / 安裝樹中 MUST 不得同時留下多份版本不同的 `@opentui/core`。

#### Scenario: 執行版本升級時
- **WHEN** 發起 OpenTUI 依賴更新
- **THEN** `@opentui/core` 與 `@opentui/solid` MUST 一併升級到同一批最新穩定版

#### Scenario: lockfile 不得留下 nested duplicate OpenTUI core
- **WHEN** 依賴安裝完成並更新 `bun.lock`
- **THEN** `tui/` 的安裝樹 MUST 不得同時存在多份版本不同的 `@opentui/core`
- **AND** 應用程式的 import 與 lockfile 結果 MUST 共同保證 bundle 只會解析到單一批次的 OpenTUI core

### Requirement: 升級後必須完成最小驗證
每次 OpenTUI 或 lockfile 管理策略變更後，開發流程 SHALL 執行最小驗證以確保可建置、可測試，且終端互動行為無回歸。

#### Scenario: 依賴更新完成後執行自動化驗證
- **WHEN** OpenTUI 版本或 lockfile 發生變更
- **THEN** MUST 成功執行 `bun install`、`bun run build`、`bun test`

#### Scenario: 依賴更新完成後執行終端互動回歸驗證
- **WHEN** OpenTUI 版本升級完成且自動化驗證已通過
- **THEN** MUST 驗證 focus/blur 切換、退出後 terminal state 還原、鍵盤控制（`p/r/s/q`）與倒數/完成畫面渲染完整性皆維持正確行為

#### Scenario: 依賴更新完成後執行 packaged runtime smoke test
- **WHEN** OpenTUI 版本或 lockfile 發生變更且 bundle 已重新建置
- **THEN** MUST 以 AppImage 或等效 packaged runtime 路徑驗證 TUI 可正常啟動
- **AND** MUST NOT 出現 duplicate OpenTUI env registry registration error
