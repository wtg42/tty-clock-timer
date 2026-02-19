## Why

OpenTUI v0.1.80 包含多項穩定性和相容性改進（Grapheme span 處理、input 緩衝、ScrollBox 偵測等），無重大變更。升級確保我們獲得最新的 bug fix 並保持依賴現代化。

## What Changes

- 將 `@opentui/core` 和 `@opentui/solid` 從 v0.1.79 升級至 v0.1.80
- 驗證 Bun plugin 在新版本中仍可正常執行 JSX 轉換
- 驗證原生包外部化策略（platform-specific `.so` 複製）仍然有效
- 測試 AppImage 打包流程能否正常執行

## Capabilities

### New Capabilities
<!-- 無新能力引入 -->

### Modified Capabilities
- `tui-bundle-build`: 驗證 @opentui/solid bun-plugin API 和原生包結構在 v0.1.80 中的相容性

## Impact

- **受影響的檔案**: `tui/package.json`、`tui/build.ts`、AppImage 打包流程
- **風險**: 低（無 breaking changes 公告，但 Bun plugin API 需要驗證）
- **測試範圍**: TUI bundle 建立、基本功能測試（start/pause/resume/reset/quit）、AppImage 大小驗證
