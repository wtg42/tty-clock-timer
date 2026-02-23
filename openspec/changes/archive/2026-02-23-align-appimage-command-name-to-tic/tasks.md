## 1. AppImage 命名一致性修正

- [x] 1.1 更新 `packaging/appimage/scripts/verify-artifact.sh`，將 core binary 檢查路徑從 `AppDir/usr/bin/tty_clock_timer` 改為 `AppDir/usr/bin/tic`。
- [x] 1.2 更新 `packaging/appimage/assets/tty-clock-timer.desktop`，將 `Exec` 值改為 `tic`。

## 2. 文件與驗證對齊

- [x] 2.1 更新 `packaging/appimage/README.md` 中仍引用 `tty_clock_timer` 的路徑或敘述，改為 `tic`。
- [x] 2.2 執行 AppImage verify（`APPIMAGE_VERSION=<version> ./packaging/appimage/scripts/verify-artifact.sh`）確認命名對齊後檢查可通過。
