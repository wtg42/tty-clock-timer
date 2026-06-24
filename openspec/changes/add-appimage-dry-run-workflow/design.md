## Context

既有 `tag-driven-appimage-release.yml` 僅在 `v*` tag push 時觸發，且包含 release credential validation 與 `gh release create/upload`。這條流程適合正式發版，但不適合在變更驗證期間反覆測試 AppImage package/verify。

AppImage package script 已包含 core build、TUI build、AppDir assembly 與 `appimagetool` packaging；verify script 已檢查 AppImage、`AppRun`、`usr/bin/tic`、TUI runtime、prompt helper、desktop file 與 icon。Dry-run workflow 應重用這些 scripts，不複製打包邏輯。

因為 dry-run 會使用 Zig master 執行既有 `build-core.sh`，workflow 必須同時包含目前已知的 Zig master compatibility 修正：`std.Build.args` 已不存在，`std.meta.fields` 也已成為 compile-time error。

## Goals / Non-Goals

**Goals:**

- 提供手動觸發的 Ubuntu AppImage package/verify dry-run。
- 讓維護者可以下載 dry-run AppImage artifact 檢查，不建立 GitHub Release。
- 讓 dry-run 使用的 core build path 可在 Zig master 下成功編譯出 `tic`。
- 保持正式 tag-driven release workflow 不變。

**Non-Goals:**

- 不新增 tag trigger、PR trigger 或 branch push trigger。
- 不修改 `package-appimage.sh`、`verify-artifact.sh` 或 release upload 流程。
- 不在 dry-run 中執行 `gh release` 或要求 write permission。
- 不重新設計 `tic` 命名契約。

## Decisions

- **Decision: 新增獨立 workflow。**  
  獨立 workflow 可避免正式 release workflow 出現 dry-run 分支條件，降低誤觸 release upload 的風險。

- **Decision: 使用 `APPIMAGE_VERSION=dry-run-${{ github.run_number }}`。**  
  產物名稱明確標示 dry-run，且不需要使用 semver tag。

- **Decision: 上傳 Actions artifact。**  
  Dry-run 產物保留 7 天供下載檢查，但不污染 GitHub Release assets。

- **Decision: 同步修正 Zig master core build blocker。**  
  Dry-run workflow 的核心價值是跑完整 package/verify；若 core build 仍卡在已移除的 Zig std API，workflow 只會重現已知失敗。使用 `Run.addPassthruArgs()` 與 `std.meta.stringToEnum()` 做最小修正，保留 binary 名稱 `tic`。

## Risks / Trade-offs

- Dry-run workflow 與正式 workflow 有部分 setup 步驟重複 → 接受少量重複換取 release 路徑隔離。
- Dry-run 只在手動觸發時執行 → 符合目前需求；若之後需要 PR 自動驗證，另開 change 加 PR trigger。
- Zig master API 仍可能持續漂移 → 本次只修目前本地 std source 與 build/test 暴露的 blocker，後續漂移再以新的 compatibility change 處理。
