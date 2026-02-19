## Why

目前 `list` 流程雖然可使用 `gum`，但 AppImage 打包並未將 `gum` 納入 runtime artifact，導致發佈版常依賴使用者系統環境或退回 fallback。這會讓互動體驗不一致，也缺少打包階段對 `gum` 存在與可執行性的明確檢查。

## What Changes

- 將 Linux x86_64 的 `gum` binary 視為 AppImage runtime tool，納入打包輸入與輸出契約。
- 調整專案內 `gum` 放置位置為 packaging 範疇（位於 `core/` 外），並定義打包目的地。
- 在打包流程加入 precheck 與 verify 檢查，確保來源與 AppDir 內 `gum` 均存在且可執行。
- 定義 core 在 AppImage 內優先使用打包工具路徑（由 runtime env 注入），找不到時維持既有 fallback 機制。
- 本次僅處理 Linux x86_64；其他平台維持現況。

## Capabilities

### New Capabilities

- 無

### Modified Capabilities

- `appimage-packaging-workflow`: 擴充 AppImage artifact contract，要求打包 Linux x86_64 `gum` 並在 build/package/verify 階段檢查。

## Impact

- Affected code:
  - `core/src/main.zig`（AppImage runtime 下 gum path 解析順序）
  - `packaging/appimage/scripts/package-appimage.sh`（copy runtime gum + AppRun env）
  - `packaging/appimage/scripts/verify-artifact.sh`（gum artifact executable check）
  - `packaging/appimage/release.md`（手動流程與檢查項目說明）
- Affected assets:
  - `packaging/tools/gum/linux-x64/gum`（作為 AppImage 工具輸入）
- 依賴與風險：增加單一平台工具 artifact 管理成本，但可提升發佈版互動一致性並保留 fallback 降低失敗風險。
