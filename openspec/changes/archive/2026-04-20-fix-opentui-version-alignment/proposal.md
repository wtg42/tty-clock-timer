## Why

目前 TUI 依賴樹同時存在不同版本的 `@opentui/core` 與 `@opentui/solid`，導致 bundle 內打入兩份 OpenTUI core，AppImage 執行時因重複註冊 `OTUI_DUMP_CAPTURES` 而直接崩潰。這個問題必須先修正，否則打包成功的產物仍不具備可執行性。

## What Changes

- 對齊 `tui/` 中 `@opentui/core` 與 `@opentui/solid` 的版本，避免 lockfile 與實際安裝樹出現雙版本 OpenTUI core。
- 調整 TUI 程式碼與 build 依賴使用方式，避免為少量型別或常數直接引入第二條 `@opentui/core` 匯入路徑。
- 補上對 bundle 與 AppImage runtime 的驗證，確認產物在目前 OpenTUI 版本組合下可正常啟動。

## Capabilities

### New Capabilities

- 無

### Modified Capabilities

- `tui-bundle-build`: 更新 TUI bundle 規範，要求產物不得同時內含多份 OpenTUI core，且 AppImage runtime 必須能在目前依賴組合下正常啟動。
- `tui-dependency-lockfile-management`: 更新依賴管理規範，要求 `@opentui/core`、`@opentui/solid` 與其 peer/lockfile 維持一致，避免 nested duplicate 安裝。

## Impact

- 影響程式碼：`tui/package.json`、`tui/bun.lock`、`tui/src/app.tsx`、`tui/build.ts`
- 影響系統：TUI bundle build、AppImage runtime 啟動流程
- 影響依賴：OpenTUI 套件版本與 lockfile 內容
