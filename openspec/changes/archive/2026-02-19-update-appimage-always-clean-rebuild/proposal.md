## Why

目前 AppImage 打包在 `stage/usr/bin/tty_clock_timer` 已存在時不會重新建置 core，導致跨機器或切換工作環境後，仍可能把舊 binary 打進新版本 AppImage。需要把打包流程改為每次先清除專案內建置產物並強制重建，確保產物內容可預期且可重現。

## What Changes

- 更新 `package-appimage.sh`，在打包前固定清理專案內 build 產物（不清全域 cache）。
- 更新 `package-appimage.sh`，每次打包都強制執行 core rebuild 與 TUI rebuild，不再依賴既有 `stage` binary。
- 保留現有 AppImage 產物命名與 appimagetool 探測行為，僅調整 build/package 前置流程。
- 補充文件，明確說明 clean rebuild 策略、清理範圍與可接受副作用（較長建置時間）。

## Capabilities

### New Capabilities
- 無

### Modified Capabilities
- `appimage-packaging-workflow`: 打包流程改為固定 clean rebuild，避免沿用舊 stage 產物。

## Impact

- 受影響檔案：`packaging/appimage/scripts/package-appimage.sh`、`packaging/appimage/README.md`。
- 受影響流程：manual release 與本地驗證打包流程。
- 預期影響：建置時間與 I/O 成本增加，但可提升產物正確性與跨環境一致性。
