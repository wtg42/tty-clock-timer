## ADDED Requirements

### Requirement: Core runtime allocator MUST 來自 std.process.Init
Core 主流程在 runtime 中 MUST 使用 `std.process.Init` 提供的 allocator 作為預設分配器來源，且目前策略 MUST 以 `init.gpa` 為主。

#### Scenario: 啟動主流程時使用 Init allocator
- **WHEN** 程式進入 `main(init: std.process.Init)` 並初始化 runtime
- **THEN** allocator 來源 MUST 來自 `init` 物件
- **AND** 不得在主流程再建立平行的自定義 allocator context

### Requirement: 不再保留未使用的自定義 allocator 模組
當自定義 allocator 模組不再被 runtime 使用時，系統 MUST 移除該模組與其測試，以避免 allocator 策略雙軌。

#### Scenario: 移除舊 allocator 模組
- **WHEN** runtime allocator 已統一為 `std.process.Init` 提供來源
- **THEN** `core/src/lib/allocator.zig` 與其測試 MUST 被移除
- **AND** 程式碼中不得殘留對舊 allocator 模組的引用

### Requirement: allocator 策略調整後功能行為 MUST 維持一致
allocator 來源調整後，CLI 參數解析、timer 執行與 IPC 事件傳遞行為 MUST 維持既有語意。

#### Scenario: 進行回歸驗證
- **WHEN** 完成 allocator 策略調整與模組清理
- **THEN** `zig build test` MUST 通過
- **AND** 以最小 CLI smoke test 驗證主流程仍可正常啟動與運作
