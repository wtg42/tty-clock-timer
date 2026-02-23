## 1. 修改 Zig 構建配置

- [x] 1.1 修改 `core/build.zig` 中的二進制輸出名稱從 `tty_clock_timer` 改為 `tic`
- [x] 1.2 驗證本地 `zig build` 生成的執行檔名為 `tic`
- [x] 1.3 驗證 `zig build run` 可正常執行新二進制

## 2. 更新 CLI 幫助文本與示例

- [x] 2.1 在 `core/src/main.zig` 中更新幫助文本，將所有 `tty_clock_timer` 改為 `tic`
- [x] 2.2 驗證 `tic --help` 和 `tic` 無參數執行顯示更新後的命令名稱
- [x] 2.3 執行測試確保幫助文本輸出無誤

## 3. 更新文檔與示例

- [x] 3.1 更新 `README.md` 中的所有命令示例從 `tty-clock-timer` 改為 `tic`
- [x] 3.2 更新 `packaging/appimage/artifact-contract.md` 中的二進制路徑及示例
- [x] 3.3 檢查其他文檔（如存在）中的命令引用並更新

## 4. 更新打包與 AppImage 構建

- [x] 4.1 修改 `packaging/appimage/scripts/build-core.sh` 中關於二進制名稱的引用
- [x] 4.2 修改 `packaging/appimage/scripts/package-appimage.sh` 以確保 AppImage 中的二進制名為 `tic`
- [x] 4.3 驗證 `packaging/appimage/artifact-contract.md` 中的運行時契約（`usr/bin/tic`）

## 5. 驗證與測試

- [x] 5.1 本地編譯並測試 `tic --minutes 25` 正常運行
- [x] 5.2 測試 `tic --seconds 30` 功能
- [x] 5.3 測試 `tic list` 與 `tic list --delete` 功能
- [x] 5.4 構建 AppImage 並驗證內部二進制確實名為 `tic`
- [x] 5.5 在 AppImage 環境中測試 `./AppRun --minutes 10` 正常運行

## 6. 文檔與通信

- [x] 6.1 更新 CHANGELOG 或版本說明註記 Breaking Change
- [x] 6.2 驗證所有變更已 commit 並準備發布
