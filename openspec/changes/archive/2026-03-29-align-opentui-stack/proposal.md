## Why

目前 `tui/` 仍停留在較早的 OpenTUI 與 `solid-js` 相依版本，和 upstream 最新 API 與相容組合存在落差。若不及早對齊版本並建立對應的 TDD 驗證，後續升級將更容易累積相容性風險、放大一次性修改成本。

## What Changes

- 對齊 `tui/` 使用的 `@opentui/core`、`@opentui/solid` 與 `solid-js` 版本，使其接近目前 upstream 建議的相容組合。
- 更新 TUI build 與 runtime contract 的版本要求，確認 native package shim、bundle 與 OpenTUI 新版仍可穩定配合。
- 補齊以 OpenTUI test renderer 為核心的 TDD 驗證，涵蓋 render output、keyboard interaction 與升級後的基本整合行為。
- 保持既有 timer UI 行為與畫面契約，避免升級相依套件時發生未被偵測的行為漂移。

## Capabilities

### New Capabilities
- `tui-render-integration-tests`: 定義以 OpenTUI headless renderer 與 `@opentui/solid` `testRender()` 驗證 TUI 畫面與互動整合行為的規格。

### Modified Capabilities
- `tui-bundle-build`: 調整 OpenTUI 相關版本對齊要求，並確認升級後 bundle 與 native shim 仍符合 build contract。
- `tui-function-unit-tests`: 擴充 TDD 驗證範圍的要求，讓升級工作除了 pure function 測試，也需能以穩定方式驗證升級前後的測試入口與回歸檢查。
- `tui-timer-display`: 明確要求升級 OpenTUI 相依套件後，倒數畫面、完成畫面與錯誤訊息等既有顯示契約必須維持穩定。

## Impact

- 影響 `tui/package.json`、`tui/build.ts`、`tui/src/index.tsx` 與相關測試檔案。
- 影響 TUI 測試策略，新增依賴 OpenTUI test renderer 的整合測試。
- 影響 OpenTUI / SolidJS dependency policy，未來版本對齊將以 upstream 相容組合與測試驗證作為基準。
