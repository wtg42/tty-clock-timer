# cli-launch-ui Delta Specification

## REMOVED Requirements

### Requirement: CLI 啟動時自動啟動 UI

**Reason**: 架構重構為 Server-Client 模型，Core 不再作為 main process spawn UI，改為由 Server spawn Core，TUI 作為獨立 HTTP client 連接 Server。

**Migration**: 使用者需先啟動 Server (`bun run server`)，再啟動 TUI client (`bun run tui`)。TUI 透過 HTTP/SSE 連接 Server，不再依賴 Core 的 process spawn。

## ADDED Requirements

### Requirement: Server 啟動 Core Process

Server SHALL 在啟動時自動 spawn Core process，透過 `Bun.spawn()` 執行 `zig-out/bin/timer-core` 並建立 stdio pipes。

#### Scenario: Server 正常啟動 Core

- **WHEN** Server 啟動且 Core binary 存在於 `zig-out/bin/timer-core`
- **THEN** Server 成功 spawn Core process 並建立 stdin/stdout 通訊管道

#### Scenario: Core Binary 不存在

- **WHEN** Server 啟動但 `zig-out/bin/timer-core` 不存在
- **THEN** Server 輸出錯誤訊息 "Core binary not found at zig-out/bin/timer-core" 並終止

#### Scenario: 從不同工作目錄啟動

- **WHEN** 使用者在 `server/` 目錄執行 `bun run server`
- **THEN** Server 仍能正確定位專案根目錄的 `zig-out/bin/timer-core`
