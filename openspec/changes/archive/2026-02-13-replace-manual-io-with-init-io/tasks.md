## 1. Core 初始化遷移

- [x] 1.1 在 `core/src/main.zig` 以 `init.io` 取代手動 `std.Io.Threaded` 初始化
- [x] 1.2 調整既有 writer/reader 取得路徑，確保輸出與 timer 互動流程維持相容

## 2. 行為相容性驗證

- [x] 2.1 驗證無參數執行仍顯示 help/usage 並正常結束
- [x] 2.2 驗證無效參數仍回傳錯誤語意且不改變既有錯誤判定流程
- [x] 2.3 於 `core/` 執行 `zig build` 與 `zig build test` 確認遷移後可編譯與測試通過

## 3. 文件同步

- [x] 3.1 更新 `README.md` 或 `core/README.md`，說明 core runtime I/O 來源改為 `std.process.Init` 的 `init.io`
