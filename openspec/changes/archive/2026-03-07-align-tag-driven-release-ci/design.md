## Context

目前 tag-driven release workflow 已移除 `fetch-gum.sh`，並在 CI 內執行 `bun install --frozen-lockfile`、`package-appimage.sh`、`verify-artifact.sh`。prompt helper artifact 的建立與檢查責任已經下沉到 packaging scripts，但 `tag-driven-appimage-release` 主 spec 仍要求下載與驗證 `gum`，造成 spec 與真實 CI 行為分離。

另外，AppImage 打包後的 TUI runtime 目前會包含 `dist/node_modules/@opentui/core-<platform>-<arch>/index.ts` shim，這是 OpenTUI native library resolution 所需的最小目錄結構；因此 `appimage-packaging-workflow` 中「不得包含 node_modules」的描述也與真實 artifact 不一致。

## Decision

1. 主修正放在 `openspec/specs/tag-driven-appimage-release/spec.md`，讓 spec 回到目前實際 workflow。
2. Failure signaling 仍維持 stage-based，但工具準備說明改成：
   - Bun setup + `bun install --frozen-lockfile`
   - `package-appimage.sh` 內建 prompt helper build/check
   - `verify-artifact.sh` 內建 prompt helper artifact verify
3. `openspec/specs/appimage-packaging-workflow/spec.md` 改為允許最小 `node_modules` shim 存在，並明確限制其用途為 native runtime shim，而非完整依賴樹。
4. 不重新引入額外的 helper preflight step，避免和既有 packaging contract 重複。

## Risks

- 若只改 spec 不改 workflow，仍需確認 workflow wording 沒殘留 gum 假設。
- 若未明確描述 helper artifact 檢查位置，維護者可能以為 CI 缺少該檢查。
- 若繼續保留「無 node_modules」描述，會讓 artifact verify 與 release 檢查的驗收基準失真。

## Validation

- 確認 workflow 內已無 `gum`/`fetch-gum.sh`。
- 確認更新後 spec 與 `.github/workflows/tag-driven-appimage-release.yml` 一致。
- 確認 `appimage-packaging-workflow` 描述與實際 AppDir 內容一致。
