## Why

目前 `package-appimage.sh` 的 `APPIMAGETOOL_BIN` 預設為 `appimagetool`，但專案故意不全域安裝此工具，而是放在 `packaging/tools/appimagetool.AppImage`（已被 gitignore）。使用者每次打包都必須手動設定環境變數，不夠順手。腳本應自動探測專案內的工具路徑。

## What Changes

- `package-appimage.sh` 新增 appimagetool 自動探測邏輯：優先環境變數、其次專案內 `packaging/tools/appimagetool.AppImage`、最後 PATH，都找不到則報錯並提示下載位置
- `verify-artifact.sh` 加入相同的探測邏輯以保持一致

## Capabilities

### New Capabilities
- `appimage-tool-discovery`: 打包腳本自動探測 appimagetool 路徑，免去手動設定環境變數

### Modified Capabilities
- `appimage-packaging-workflow`: 打包流程不再強制要求使用者手動設定 `APPIMAGETOOL_BIN`

## Impact

- 影響檔案：`packaging/appimage/scripts/package-appimage.sh`、`packaging/appimage/scripts/verify-artifact.sh`
- 無 breaking change，既有環境變數設定仍優先生效
