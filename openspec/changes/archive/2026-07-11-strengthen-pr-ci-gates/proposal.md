## Why

目前 `main` 沒有 branch protection、ruleset 或 required status checks，因此 CI 失敗時 GitHub 仍可能允許合併；同時 Linux AppImage PR workflow 只驗證 build/package，沒有在 Ubuntu 執行 Zig 與 TUI tests。macOS 支援準備合併前，應將兩平台驗證提升為明確且可強制執行的 merge gate。

## What Changes

- 讓 Linux AppImage PR dry-run 在 package 前執行 `zig build test` 與完整 Bun test suite。
- 讓只修改 tag-driven release workflow 的 PR 也觸發 Linux AppImage dry-run。
- 保持 macOS dry-run 執行 Zig tests、TUI tests、package、native dylib/IPC smoke 與 failure diagnostics。
- 為 Linux 與 macOS PR workflows 設定穩定、不因 step 文案調整而改變的 check identity。
- 在 GitHub `main` branch 啟用 pull request requirement 與 required status checks，要求 Linux、macOS checks 成功且 branch 已與 `main` 同步後才能合併。
- 文件化 branch protection 的設定、驗證、回復方式，以及新 workflow 首次推送後才能選取 required checks 的 bootstrap 順序。
- 為 PR workflows 加入 concurrency，取消同一 PR 已過時的執行以節省 runner 時間。

## Capabilities

### New Capabilities

- `pull-request-ci-gates`: 定義跨平台 PR 測試矩陣、穩定 check identity、required checks、branch protection 與 merge gate 行為。

### Modified Capabilities

- `tag-driven-appimage-release`: 擴充 Linux AppImage PR dry-run，使其執行 Zig/TUI tests，並在 tag-driven release workflow 本身變更時觸發。

## Impact

- 受影響檔案：`.github/workflows/appimage-dry-run.yml`、`.github/workflows/macos-dry-run.yml` 與 CI 維護文件。
- 受影響外部設定：GitHub repository `main` branch protection/ruleset；此設定不儲存在 Git tree 中，套用時需要 repository admin 權限。
- Merge 行為：PR 必須通過兩平台 required checks 並保持 up to date，維護者不再能在 checks 失敗或缺失時正常合併。
- Change dependency：本 change 依賴 `add-macos-support` 所建立的 `macos-dry-run` workflow，兩者應在同一 feature branch/PR 內依序實作及驗證。
