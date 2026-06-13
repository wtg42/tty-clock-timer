## Why

OpenTUI 已從專案目前鎖定的 `0.1.102` 推進到最新穩定版 `0.4.1`，跨越多個 minor 版本後再升級會提高 API、peer dependency 與 native package 解析漂移風險。

這次變更要把 TUI stack 對齊到最新穩定 OpenTUI，並用 TDD 與既有 build/runtime 驗證保護倒數畫面、鍵盤互動與 packaged runtime 行為。

## What Changes

- 將 `@opentui/core` 與 `@opentui/solid` 升級到 npm latest stable `0.4.1`。
- 將 `solid-js` 對齊 `@opentui/solid@0.4.1` 的 peer expectation。
- 更新 `tui/bun.lock`，維持 Bun lockfile 為唯一依賴來源。
- 先以測試/驗證覆蓋升級敏感契約，再更新依賴與必要相容性修正。
- 檢查並修正 TUI bundle 對 OpenTUI native package 與 shim 的處理，確保 build 產物仍可載入 native library 且不含 duplicate OpenTUI core。
- 不引入第三方 Zig package；Zig core 行為僅透過既有 runtime contract 驗證。

## Capabilities

### New Capabilities

- 無。

### Modified Capabilities

- `tui-dependency-lockfile-management`: 確認 OpenTUI latest stable 升級流程與 TDD/最小驗證結果可落實。
- `tui-bundle-build`: 補強升級後 native package external/shim 相容性，涵蓋 OpenTUI `0.4.x` 的 native package 形狀。
- `tui-render-integration-tests`: 使用 renderer-based tests 作為 OpenTUI 升級前後的 UI regression safety net。

## Impact

- Affected code: `tui/package.json`, `tui/bun.lock`, `tui/build.ts`, `tui/src/*.test.tsx`。
- Affected dependencies: `@opentui/core`, `@opentui/solid`, `solid-js`，以及 lockfile 中的 transitive dependencies。
- Affected systems: TUI renderer、keyboard handling、finished/countdown rendering、Bun bundle、native OpenTUI library packaging。
