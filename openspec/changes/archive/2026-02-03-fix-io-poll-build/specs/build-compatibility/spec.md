## ADDED Requirements

### Requirement: Zig master build succeeds
系統在 Zig master 環境中 MUST 能成功編譯並執行核心 CLI。

#### Scenario: Build and run successfully
- **WHEN** 開發者執行 `zig build run -- --seconds 3`
- **THEN** 編譯與執行流程 MUST 成功完成，不得因 `std.Io` API 不相容而失敗
