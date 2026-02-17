## 1. 實作探測邏輯

- [x] 1.1 在 `package-appimage.sh` 中將 `APPIMAGETOOL_BIN` 的單行 fallback 替換為三層探測邏輯（環境變數 → `packaging/tools/appimagetool.AppImage` → PATH），找不到時輸出錯誤訊息並以非零退出碼結束
- [x] 1.2 在 `verify-artifact.sh` 中加入相同的探測邏輯，確保 `APPIMAGE_VERSION` 與 `APPIMAGE_NAME` 可正確解析（實際不需修改，該腳本不使用 appimagetool）

## 2. 驗證

- [x] 2.1 不設定 `APPIMAGETOOL_BIN`，直接執行 `package-appimage.sh`，確認自動使用專案內工具
- [x] 2.2 設定 `APPIMAGETOOL_BIN` 為自訂路徑，確認環境變數優先
- [x] 2.3 移除專案內工具並取消環境變數，確認錯誤訊息正確輸出
