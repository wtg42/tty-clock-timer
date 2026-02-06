## Why

目前 timer 內部以 `std.Options.debug_io` 取得時間，與 `main` 已建立的 `Io` 實例來源不一致，容易造成語意混淆與後續維護風險。將 timer 改為使用 `main` 注入的 `Io` 可統一執行期 I/O 與時鐘上下文，讓計時邏輯更可預期且更貼近正式執行路徑。

## What Changes

- 調整 timer 模組 API，讓 `start`、`unpause`、`update` 等需要取時間的流程改為使用呼叫端注入的 `std.Io`。
- 更新 `main` 中 timer 呼叫點，改以已初始化的 `io` 傳入 timer，而非讓 timer 自行依賴 `std.Options.debug_io`。
- 補強測試與驗證，確認狀態轉換與倒數遞減語意在注入 `Io` 後保持一致。

## Capabilities

### New Capabilities
- 無。

### Modified Capabilities
- `build-compatibility`: 更新需求以明確規範倒數計時核心 MUST 使用應用程式執行期 `Io` 上下文進行時間讀取，避免依賴 `std.Options.debug_io`。

## Impact

- Affected code: `core/src/lib/timer.zig`、`core/src/main.zig`、timer 相關測試。
- APIs/behavior: 僅內部函式簽名與呼叫路徑調整；CLI 對外參數與輸出行為維持不變。
- Dependencies: 無新增外部依賴，維持 Zig std 內建 `Io` API。
- Systems: 影響 core timer 的時間來源一致性與可維護性。
