## Why

專案升級到 Zig 0.17 後，Core 在編譯 `config.zig` 的動態 JSON object 操作時失敗，導致 AppImage 打包流程無法產出核心二進位。這個問題必須先修正，否則既有 CLI 與設定檔流程都無法在目前 Zig 標準庫版本下持續維護與發佈。

## What Changes

- 調整 Core 中動態 JSON object 的建立、插入與釋放方式，以符合 Zig 0.17 `std.json` / `std.array_hash_map` API。
- 保持既有用戶設定檔行為不變，特別是 `sound` 欄位的合併寫入邏輯與其他欄位保留行為。
- 補上針對 Zig 0.17 相容性的驗證，確保 Core build 與 AppImage 包裝流程不再因舊版 `std` API 用法中斷。

## Capabilities

### New Capabilities

- 無

### Modified Capabilities

- `build-compatibility`: 更新對 Zig master / Zig 0.17 標準庫相容性的要求，確保 Core 可在現行 `std.json` API 下成功編譯並支援既有設定檔流程。

## Impact

- 影響程式碼：`core/src/lib/config.zig` 與其相關測試／建置驗證流程
- 影響系統：Core CLI build、AppImage 打包流程
- 不預期改變使用者 CLI 介面或設定檔格式
