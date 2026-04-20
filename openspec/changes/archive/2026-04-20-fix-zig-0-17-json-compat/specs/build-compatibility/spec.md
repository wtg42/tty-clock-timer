## MODIFIED Requirements

### Requirement: Zig master build succeeds
系統在 Zig master 與 Zig 0.17 相容環境中 MUST 能成功編譯並執行核心 CLI，且計時核心 MUST 不依賴已移除的 `std.time.Timer`，MUST 使用應用程式執行期注入的 `std.Io` 上下文進行時間讀取，並 MUST 在用戶設定檔合併流程中使用目前 `std.json` / `std.array_hash_map` 支援的 API。

#### Scenario: Build and run successfully
- **WHEN** 開發者執行 `zig build run -- --seconds 3`
- **THEN** 編譯與執行流程 MUST 成功完成，不得因 `std.time`、`std.Io` 或 `std.json` API 不相容而失敗

#### Scenario: Countdown timer works on Zig master APIs
- **WHEN** 倒數計時器在 running 狀態下執行更新流程
- **THEN** 系統 MUST 以 Zig master 可用的時間 API 計算經過時間，並正確遞減剩餘秒數直到完成

#### Scenario: Timer reads time from main runtime Io context
- **WHEN** `main` 初始化 `std.Io.Threaded` 並將 `io` 傳入 timer 的時間相關操作
- **THEN** timer 的 `start`、`unpause`、`update` MUST 使用該注入 `io` 取得時間，且 MUST NOT 依賴 `std.Options.debug_io`

#### Scenario: Config merge logic compiles on current std JSON APIs
- **WHEN** Core 編譯包含用戶設定檔 `sound` 欄位合併寫入邏輯
- **THEN** `config.zig` 的動態 JSON object 建立、欄位插入與釋放 MUST 使用目前 Zig 版本可用的 `std.json` / `std.array_hash_map` 介面，且不得因舊版 object map API 用法造成編譯失敗
