## Why

`tag-driven-appimage-release` 的主 spec 仍描述舊的 `gum` 準備階段，但 GitHub Actions workflow 已改為依賴 Bun install 與 packaging/verify 腳本來產生並檢查 `prompts/helper.js`。另外，`appimage-packaging-workflow` 仍宣稱 AppImage 不包含 `node_modules`，但目前實際產物會攜帶最小的 OpenTUI native shim 目錄。這些規格與實作不一致，會讓後續維護者誤判 release pipeline 與 artifact contract。

## What Changes

- 更新 `tag-driven-appimage-release` spec，移除 `gum` 下載/checksum 描述。
- 將 workflow 前置需求改為 Bun 依賴安裝與既有 packaging/verify 腳本的 artifact 檢查責任。
- 補上 prompt helper artifact 對齊後的 failure signaling 說明。
- 更新 `appimage-packaging-workflow` spec，反映目前 AppImage runtime 仍包含最小 `node_modules` shim 的現況。

## Impact

- `openspec/specs/tag-driven-appimage-release/spec.md`
- `openspec/specs/appimage-packaging-workflow/spec.md`
- 若需要小幅 CI wording 對齊，則包含 `.github/workflows/tag-driven-appimage-release.yml`
