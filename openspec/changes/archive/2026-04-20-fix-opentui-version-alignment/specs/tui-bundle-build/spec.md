## MODIFIED Requirements

### Requirement: TUI MUST 可透過 bun build 產出單一 JS bundle
系統 MUST 提供 build script（`tui/build.ts`），使用 `Bun.build()` 搭配 `@opentui/solid/bun-plugin` 將 `src/index.tsx` 及其所有 JS/TS 依賴打包為單一 bundle 檔案，輸出至 `tui/dist/`。依賴版本 MUST 以同一批次的 `@opentui/core` 與 `@opentui/solid` 為準，且 `solid-js` MUST 對齊該批次 `@opentui/solid` 的 peer expectation，以降低未來 API 漂移與 peer mismatch 風險。產出的 bundle MUST NOT 同時內含多份版本不同的 OpenTUI core，且應用程式層不得因直接額外匯入 `@opentui/core` 而重新引入第二份 core module graph。

#### Scenario: 執行 build 產出 bundle
- **WHEN** 開發者在 `tui/` 目錄執行 `bun run build`
- **THEN** 系統 MUST 在 `tui/dist/` 產出可由 `bun` 直接執行的 JS bundle 檔案

#### Scenario: bundle 不得同時包含多份 OpenTUI core
- **WHEN** build 完成後檢視產出的 `tui/dist/index.js`
- **THEN** bundle 中 MUST 僅包含一份 OpenTUI core 的 env registry / renderer 初始化路徑
- **AND** 不得因兩份不同版本 core 重複註冊 `OTUI_DUMP_CAPTURES` 等全域 env var 而在啟動時崩潰

### Requirement: Bundle 產物 MUST 可獨立執行
產出的 bundle + `libopentui.so` MUST 可在不依賴 `node_modules` 的情況下由 `bun` 正確執行。

#### Scenario: 無 node_modules 環境下執行 bundle
- **WHEN** 將 `tui/dist/` 複製到不含 `node_modules` 的獨立目錄並以 `bun` 執行
- **THEN** 程式 MUST 正常啟動並渲染 TUI 畫面

#### Scenario: 打包後 runtime 啟動不因重複 env registry 崩潰
- **WHEN** 使用 TUI build 產物建出的 AppImage 或等效 runtime 執行入口啟動 TUI
- **THEN** 程式 MUST 正常啟動
- **AND** MUST NOT 因 OpenTUI env registry duplicate registration error 而在初始化階段退出
