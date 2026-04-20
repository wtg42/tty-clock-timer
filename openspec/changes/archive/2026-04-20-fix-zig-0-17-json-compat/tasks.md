## 1. Core 相容性修正

- [x] 1.1 更新 `core/src/lib/config.zig` 的動態 JSON object 建立方式，改用 Zig 0.17 相容的 `std.json.ObjectMap` 初始化寫法
- [x] 1.2 更新 `sound` 欄位寫入與釋放邏輯，讓 `put` / `deinit` 呼叫符合目前 `std.array_hash_map` allocator 介面
- [x] 1.3 確認設定檔合併流程仍保留既有欄位，且不改變 `sound` 寫入結果

## 2. 建置與打包驗證

- [x] 2.1 執行 `zig build -Dtarget=x86_64-linux -Doptimize=ReleaseSafe`，確認 Core 在 Zig 0.17 下可成功編譯
- [x] 2.2 重新執行 AppImage 打包流程，確認不再因 `config.zig` 的舊版 `std.json` API 用法中斷
