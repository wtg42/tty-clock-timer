## MODIFIED Requirements

### Requirement: Zig master build succeeds
系統在 Zig master 環境中 MUST 能成功編譯並執行核心 CLI，且計時核心 MUST 不依賴已移除的 `std.time.Timer`。

#### Scenario: Build and run successfully
- **WHEN** 開發者執行 `zig build run -- --seconds 3`
- **THEN** 編譯與執行流程 MUST 成功完成，不得因 `std.time` 或 `std.Io` 時間 API 不相容而失敗

#### Scenario: Countdown timer works on Zig master APIs
- **WHEN** 倒數計時器在 running 狀態下執行更新流程
- **THEN** 系統 MUST 以 Zig master 可用的時間 API 計算經過時間，並正確遞減剩餘秒數直到完成
