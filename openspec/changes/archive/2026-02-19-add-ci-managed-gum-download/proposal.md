## Why

目前 `gum` binary 若不放在 repo，打包流程會缺少必要工具，造成本機與 CI 行為不一致。需要建立可重現的「自動下載 + 校驗 + 放置」流程，避免手動管理二進位檔。

## What Changes

- 新增共用腳本 `packaging/appimage/scripts/fetch-gum.sh`，統一處理 Linux x86_64 `gum` 下載、版本固定與 checksum 驗證。
- 更新 AppImage release workflow，在打包前執行 fetch 腳本，確保 CI 不依賴 repo 內 binary。
- 更新 `.gitignore`，忽略 `packaging/tools/gum/`，避免誤提交下載後二進位檔。
- 補充打包文件，說明本機與 CI 都應使用相同 fetch 腳本準備 `gum`。

## Capabilities

### New Capabilities

- 無

### Modified Capabilities

- `appimage-packaging-workflow`: 新增「打包前可由腳本取得 gum 並驗證完整性」的流程要求。
- `tag-driven-appimage-release`: 新增「CI release workflow 必須先準備 gum 工具再打包」的要求。

## Impact

- Affected code:
  - `.github/workflows/tag-driven-appimage-release.yml`
  - `packaging/appimage/scripts/fetch-gum.sh`（新增）
  - `.gitignore`
  - `packaging/appimage/release.md`
- Affected process:
  - AppImage 打包前置步驟改為腳本化下載 `gum`
- 風險：下載來源失效或 checksum 未更新會讓 CI fail fast；但可避免不受控 binary 漂移。
