## Context

既有 `tag-driven-appimage-release.yml` 僅在 `v*` tag push 時觸發，且包含 release credential validation 與 `gh release create/upload`。這條流程適合正式發版，但不適合在變更驗證期間反覆測試 AppImage package/verify。

新加入的 `workflow_dispatch` workflow 在 workflow 檔尚未存在於 default branch 前，無法直接從 GitHub Actions API 或 UI 觸發。為了讓此 PR 合併前也能驗證 AppImage package/verify，dry-run workflow 需要同時支援受限範圍的 `pull_request` trigger。

AppImage package script 已包含 core build、TUI build、AppDir assembly 與 `appimagetool` packaging；verify script 已檢查 AppImage、`AppRun`、`usr/bin/ttc`、TUI runtime、prompt helper、desktop file 與 icon。Dry-run workflow 應重用這些 scripts，不複製打包邏輯。

因為 dry-run 會使用 Zig master 執行既有 `build-core.sh`，workflow 必須同時包含目前已知的 Zig master compatibility 修正：`std.Build.args` 已不存在，`std.meta.fields` 也已成為 compile-time error。

## Goals / Non-Goals

**Goals:**

- 提供手動觸發的 Ubuntu AppImage package/verify dry-run。
- 提供 merge 前 PR AppImage package/verify dry-run，僅在影響 workflow、core、packaging 或 TUI 的路徑變更時執行。
- 讓維護者可以下載 dry-run AppImage artifact 檢查，不建立 GitHub Release。
- 讓 dry-run 使用的 core build path 可在 Zig master 下成功編譯出 `ttc`。
- 保持正式 tag-driven release workflow 不變。

**Non-Goals:**

- 不新增 tag trigger 或 branch push trigger。
- 不修改 `package-appimage.sh`、`verify-artifact.sh` 或 release upload 流程。
- 不在 dry-run 中執行 `gh release` 或要求 write permission。
- 不重新設計 `ttc` 命名契約。

## Decisions

- **Decision: 新增獨立 workflow。**  
  獨立 workflow 可避免正式 release workflow 出現 dry-run 分支條件，降低誤觸 release upload 的風險。

- **Decision: 加入受限 `pull_request` trigger。**
  `workflow_dispatch` 對新 workflow 的 default branch 限制會阻止 merge 前驗證；加入 `pull_request` trigger 可讓 PR 先跑同一條 dry-run。使用 `paths` 限制在 `.github/workflows/appimage-dry-run.yml`、`core/**`、`packaging/appimage/**` 與 `tui/**`，避免文檔或不相關變更觸發高成本 AppImage package。

- **Decision: 使用 `APPIMAGE_VERSION=dry-run-${{ github.run_number }}`。**  
  產物名稱明確標示 dry-run，且不需要使用 semver tag。

- **Decision: 上傳 Actions artifact。**  
  Dry-run 產物保留 7 天供下載檢查，但不污染 GitHub Release assets。

- **Decision: 同步修正 Zig master core build blocker。**  
  Dry-run workflow 的核心價值是跑完整 package/verify；若 core build 仍卡在已移除的 Zig std API，workflow 只會重現已知失敗。使用 `Run.addPassthruArgs()` 與 `std.meta.stringToEnum()` 做最小修正，保留 binary 名稱 `ttc`。

## Risks / Trade-offs

- Dry-run workflow 與正式 workflow 有部分 setup 步驟重複 → 接受少量重複換取 release 路徑隔離。
- Dry-run 會在相關 PR 變更時自動執行 → 比純手動多消耗 Actions minutes，但可在 workflow 合併前驗證 AppImage package path。
- Zig master API 仍可能持續漂移 → 本次只修目前本地 std source 與 build/test 暴露的 blocker，後續漂移再以新的 compatibility change 處理。
