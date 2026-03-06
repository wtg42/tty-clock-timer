## 1. 依賴與 lockfile 升級

- [x] 1.1 將 `tui/package.json` 的 `@opentui/core` 與 `@opentui/solid` 同步更新為 `0.1.86`
- [x] 1.2 重新產生並提交 `tui/bun.lock`，確認 native 子套件版本同步至 `0.1.86`

## 2. 建置與產物契約驗證

- [x] 2.1 執行 `bun install`，確認安裝成功且未產生非預期 lockfile
- [x] 2.2 執行 `bun run build`，確認 `tui/dist/` 產出 bundle 與對應 native library 檔案
- [x] 2.3 驗證 `dist/node_modules/@opentui/core-<platform>-<arch>/index.ts` shim 可正確解析 native library 路徑

## 3. 測試與終端互動回歸

- [x] 3.1 執行 `bun test`，確認既有單元測試全數通過
- [x] 3.2 手動驗證 focus/blur 切換後鍵盤操作（`p/r/s/q`）與狀態轉換仍正確
- [x] 3.3 手動驗證 `quit` 後 terminal state 還原，且倒數/完成畫面無文字破碎或錯位

## 4. 收尾與回滾準備

- [x] 4.1 記錄驗證結果與使用的 terminal emulator 組合，作為升級證據
- [x] 4.2 若驗證失敗，回復依賴與 lockfile 至升級前版本並整理失敗觀察（本次未觸發）
