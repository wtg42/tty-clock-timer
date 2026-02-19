## 1. Core runtime gum 解析調整

- [x] 1.1 在 `core/src/main.zig` 新增 `TTY_CLOCK_GUM_BIN` 優先解析，僅在路徑可用時採用
- [x] 1.2 保留既有本地相對路徑與 PATH `gum` 退路，確保失敗時仍回到 fallback 選單
- [x] 1.3 補齊/更新對應單元測試，覆蓋 env override 與退路行為

## 2. AppImage 打包與驗證流程更新

- [x] 2.1 將 Linux x86_64 `gum` 來源固定為 `packaging/tools/gum/linux-x64/gum`，並在 package 腳本加入存在與 executable precheck
- [x] 2.2 在 package 腳本將 `gum` 複製到 `AppDir/usr/lib/tty-clock-timer/tools/gum/linux-x64/gum`，並於 AppRun 注入 `TTY_CLOCK_GUM_BIN`
- [x] 2.3 在 `verify-artifact.sh` 新增 AppDir `gum` 存在與 executable 檢查，失敗時回報非零

## 3. 文件與驗收

- [x] 3.1 更新 `packaging/appimage/release.md`，補充 `gum` preflight、打包輸入與 verify 檢查項
- [x] 3.2 執行打包驗證流程（build/package/verify）確認 `gum` 被正確帶入 AppImage
- [x] 3.3 執行 `openspec validate update-appimage-bundled-gum-linux-x64 --strict` 並修正所有驗證問題
