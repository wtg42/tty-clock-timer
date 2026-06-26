## 1. OpenSpec

- [x] 1.1 建立 `add-appimage-dry-run-workflow` proposal、design、delta spec 與 tasks。
- [x] 1.2 執行 `openspec validate add-appimage-dry-run-workflow --strict`。

## 2. Workflow

- [x] 2.1 新增獨立 `.github/workflows/appimage-dry-run.yml`。
- [x] 2.2 設定 `workflow_dispatch`、`ubuntu-24.04`、`contents: read`。
- [x] 2.3 重用既有 setup 與 packaging scripts，執行 Bun install、AppImage package 與 verify。
- [x] 2.4 將 dry-run AppImage 產物上傳為 Actions artifact，retention 7 days。
- [x] 2.5 加入受限 `pull_request` trigger，讓相關 PR 變更可在 merge 前跑 AppImage dry-run。

## 3. Zig Compatibility

- [x] 3.1 更新 `core/build.zig`，以 `run_cmd.addPassthruArgs()` 取代 `std.Build.args` 分支，並保留 executable name `tic`。
- [x] 3.2 更新 `core/src/lib/ipc.zig`，以 `std.meta.stringToEnum(Command, value)` 取代 `std.meta.fields(Command)` 手動 parsing。
- [x] 3.3 在 `core/` 執行 `zig build`、`zig build test` 與 Linux x86_64 cross compile。

## 4. Verification

- [x] 4.1 靜態檢查 workflow 不包含 `gh release`、`contents: write` 或 tag-only trigger。
- [x] 4.2 靜態檢查 workflow 使用既有 packaging scripts，不複製打包邏輯。
- [x] 4.3 確認既有 tag-driven release workflow 未被修改。
- [x] 4.4 靜態檢查 PR trigger 只針對 `main` 與相關路徑執行。
- [x] 4.5 重新執行 `openspec validate add-appimage-dry-run-workflow --strict`。
- [x] 4.6 更新 `tasks.md` 勾選狀態。
