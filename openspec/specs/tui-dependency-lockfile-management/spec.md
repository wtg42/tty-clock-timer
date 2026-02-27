# tui-dependency-lockfile-management Specification

## Purpose
定義 `tui/` 專案在依賴管理、OpenTUI 升級與最小驗證流程的規範，確保 lockfile 策略一致且升級可驗證。

## Requirements

### Requirement: TUI lockfile single source of truth
`tui/` 專案在依賴管理上 MUST 以 Bun 作為唯一套件管理工具，且 SHALL 僅使用 `bun.lock` 作為 lockfile。

#### Scenario: npm lockfile 不得存在於 TUI 專案
- **WHEN** 對 `tui/` 進行依賴更新或安裝
- **THEN** 倉庫中 SHALL 不存在 `tui/package-lock.json`

#### Scenario: 依賴變更必須反映於 bun lockfile
- **WHEN** `tui/package.json` 的 dependencies 或版本範圍發生變更
- **THEN** `tui/bun.lock` MUST 同步更新且可重現安裝結果

### Requirement: OpenTUI 套件版本需維持最新穩定版
`@opentui/core` 與 `@opentui/solid` 在升級工作中 SHALL 更新至當下最新穩定版本，以降低未來跨多版跳升級風險。

#### Scenario: 執行版本升級時
- **WHEN** 發起 OpenTUI 依賴更新
- **THEN** `@opentui/core` 與 `@opentui/solid` MUST 一併升級到同一批最新穩定版

### Requirement: 升級後必須完成最小驗證
每次 OpenTUI 或 lockfile 管理策略變更後，開發流程 SHALL 執行最小驗證以確保可建置與可測試。

#### Scenario: 依賴更新完成後
- **WHEN** OpenTUI 版本或 lockfile 發生變更
- **THEN** MUST 成功執行 `bun install`、`bun run build`、`bun test`
