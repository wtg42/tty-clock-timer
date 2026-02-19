## 1. 打包腳本 clean rebuild 調整

- [x] 1.1 更新 `packaging/appimage/scripts/package-appimage.sh`：在打包流程開始前清理 `packaging/out/appimage/stage`、`packaging/out/appimage/AppDir`、`core/zig-out`、`core/.zig-cache`、`tui/dist`
- [x] 1.2 更新 `packaging/appimage/scripts/package-appimage.sh`：移除依賴既有 stage binary 的條件分支，改為每次固定執行 `build-core.sh`
- [x] 1.3 更新 `packaging/appimage/scripts/package-appimage.sh`：保留 appimagetool 自動探測與輸出命名行為，確保本次僅改動 clean/build 前置流程

## 2. 文件與驗證

- [x] 2.1 更新 `packaging/appimage/README.md`：補充每次打包皆為 repo-local clean rebuild 的預設行為與清理範圍
- [x] 2.2 執行 `APPIMAGE_VERSION=<version> ./packaging/appimage/scripts/package-appimage.sh` 驗證可正常產生 AppImage
- [x] 2.3 執行 `APPIMAGE_VERSION=<version> ./packaging/appimage/scripts/verify-artifact.sh` 驗證產物命名與必要檔案存在
