## 1. 更新依賴

- [x] 1.1 更新 `tui/package.json` 中 `@opentui/core` 為 v0.1.80
- [x] 1.2 更新 `tui/package.json` 中 `@opentui/solid` 為 v0.1.80
- [x] 1.3 執行 `cd tui && bun install` 安裝新版本

## 2. 驗證 Build 流程

- [x] 2.1 執行 `cd tui && bun run build` 驗證編譯成功
- [x] 2.2 檢查 `tui/dist/` 中 `index.js` 存在且大小合理
- [x] 2.3 檢查 `tui/dist/` 中 `libopentui.so` 已正確複製
- [x] 2.4 檢查 `tui/dist/node_modules/` 中 shim 檔案正確產出
- [x] 2.5 驗證無 TypeScript 編譯錯誤或警告

## 3. 測試 TUI 基本功能

- [x] 3.1 啟動應用（若有開發模式：`bun run dev` 或類似）
- [x] 3.2 驗證倒計時顯示正常（時間格式和數字正確）
- [x] 3.3 測試 `p` 鍵暫停功能
- [x] 3.4 測試 `r` 鍵恢復功能
- [x] 3.5 測試 `s` 鍵重設功能
- [x] 3.6 測試 `q` 鍵結束功能
- [x] 3.7 驗證無異常輸出或崩潰

## 4. 測試 AppImage 打包

- [x] 4.1 執行 `cd packaging/appimage && bash scripts/package-appimage.sh` 打包
- [x] 4.2 驗證 AppImage 產出至正確位置
- [x] 4.3 檢查 AppImage 大小（預期 ~2.8MB ±10%）
- [x] 4.4 驗證舊 AppImage 與新 AppImage 大小差異在合理範圍

## 5. 驗證 AppImage 執行和功能

- [x] 5.1 執行新生成的 AppImage（`./<appimage-name>.AppImage`）
- [x] 5.2 驗證 TUI 正常啟動
- [x] 5.3 執行快速功能測試（設定計時器、暫停、恢復、退出）
- [x] 5.4 驗證計時器精確性（計時至少 30 秒）
- [x] 5.5 驗證無記憶體洩漏或崩潰

## 6. 最終驗證和清理

- [x] 6.1 確認所有變更已提交或準備好提交
- [x] 6.2 記錄升級過程中發現的任何問題或邊際情況
- [x] 6.3 若升級失敗，執行回滾計劃（還原至 v0.1.79）
- [x] 6.4 更新專案文件（如 CHANGELOG、README 依需求）
