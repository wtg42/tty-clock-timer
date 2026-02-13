## Why

目前 `core/src/main.zig` 仍手動建立 `std.Io.Threaded` 實例，與已導入的 Juice Main (`std.process.Init`) 使用模式不一致，增加初始化路徑與維護成本。
在 Zig master 持續演進下，改用 `init.io` 可讓 runtime 資源來源一致，降低 API 漂移與重複初始化的風險。

## What Changes

- 以 `std.process.Init` 提供的 `init.io` 取代手動建立的 `std.Io.Threaded` 實例。
- 調整 `main.zig` 與相關初始化流程，確保 timer 執行與輸出行為維持一致。
- 更新對應文件，明確記錄 core runtime 的 I/O 來源來自 Juice Main。

## Capabilities

### New Capabilities
- `core-init-io-strategy`: 定義 core runtime 必須使用 `std.process.Init` 提供的 `init.io`，並維持既有 CLI/timer 可觀察行為。

### Modified Capabilities

## Impact

- 主要影響 `core/src/main.zig` 的初始化與 I/O 建立路徑。
- 可能影響 runtime 資源生命週期與錯誤邊界處理，但不應改變 CLI 參數語意或 timer 狀態機。
- 文件面將更新 `README.md` 或 `core/README.md` 中對 allocator/io 初始化策略的描述。
