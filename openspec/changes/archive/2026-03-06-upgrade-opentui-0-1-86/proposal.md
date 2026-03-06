## Why

目前 `tui/` 仍使用 `@opentui/core` 與 `@opentui/solid` `0.1.84`，未包含上游 `0.1.85` 與 `0.1.86` 的 terminal mode、mouse mode、palette 容錯與文字 continuation cell 修正。此差距會提高終端相容性問題與後續跨多版升級成本，因此需要儘速補齊到最新穩定版 `0.1.86`。

## What Changes

- 將 `tui/package.json` 的 `@opentui/core` 與 `@opentui/solid` 版本同步升級至 `0.1.86`。
- 更新 `tui/bun.lock` 與對應 native 子套件版本，維持 lockfile 可重現性。
- 在既有最小驗證之外，補強終端互動回歸檢查：focus/blur、退出後 terminal state、鍵盤操作與畫面完整性。
- 確認 `tui/build.ts` 的 native 套件解析與 `dist` shim 流程在 `0.1.86` 仍可正確運作。

## Capabilities

### New Capabilities
- （無）

### Modified Capabilities
- `tui-dependency-lockfile-management`: OpenTUI 升級後的最小驗證需求擴充為包含終端互動回歸檢查，不只安裝/建置/測試命令成功。
- `tui-bundle-build`: 依賴版本基準提升至 `0.1.86`，並明確要求升級後 native binding 解析流程仍需可用。

## Impact

- 受影響目錄：`tui/`（`package.json`、`bun.lock`、可能的 build 相關檔案與測試/驗證腳本）。
- 受影響依賴：`@opentui/core`、`@opentui/solid` 與其平台 native 套件。
- 受影響系統：TUI 執行期終端互動行為（focus/blur、terminal mode restore、鍵盤輸入、畫面渲染）。
