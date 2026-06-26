## Why

目前完整 Linux AppImage package/verify 流程只能在 GitHub Actions 的 Ubuntu runner 上可靠驗證；本機 macOS arm64 無法直接執行 x86_64 Linux `appimagetool.AppImage`。

既有 workflow 只在 `v*` tag push 時執行，且會建立或更新 GitHub Release。維護者需要一個不發版、不推 tag 的 dry-run 路徑，先驗證 AppImage build/package/verify 是否正常；同時，新 workflow 在尚未合併到 default branch 前無法直接用 `workflow_dispatch` 觸發，因此 PR 也需要能跑同一條 dry-run 驗證。

## What Changes

- 新增獨立的 GitHub Actions workflow，以 `workflow_dispatch` 手動觸發 AppImage dry-run。
- 讓同一個 dry-run workflow 在影響 AppImage build path 的 PR 上自動執行，支援 merge 前驗證。
- dry-run workflow 在 Ubuntu runner 上執行 Zig/Bun setup、TUI dependency install、AppImage package 與 verify。
- 修正 dry-run build path 會遇到的 Zig master compatibility blocker，確保 core 能在 workflow 的 Zig master 環境中編譯。
- dry-run workflow 上傳 AppImage 產物為 GitHub Actions artifact，保留 7 天供檢查。
- dry-run workflow 不建立 GitHub Release、不上傳 release assets、不需要 `contents: write`。
- 保留既有 tag-driven release workflow，不修改正式 `v*` tag 發版路徑。

## Capabilities

### New Capabilities

無。

### Modified Capabilities

- `tag-driven-appimage-release`: 增加手動與 PR AppImage dry-run 驗證路徑，明確區分 dry-run artifact 與正式 GitHub Release assets。

## Impact

- Affected systems: GitHub Actions AppImage verification。
- Affected files: `.github/workflows/appimage-dry-run.yml`、`core/build.zig`、`core/src/lib/ipc.zig`、OpenSpec change artifacts。
- No changes to packaging scripts, release upload behavior, or TUI/OpenTUI dependencies.
