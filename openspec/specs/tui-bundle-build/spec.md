# tui-bundle-build Specification

## Purpose
定義 TUI 的 bun build 流程，包含 Solid plugin 整合、external native binding 處理、產物規格。

## Requirements

### Requirement: TUI MUST 可透過 bun build 產出單一 JS bundle
系統 MUST 提供 build script（`tui/build.ts`），使用 `Bun.build()` 搭配 `@opentui/solid/bun-plugin` 將 `src/index.tsx` 及其所有 JS/TS 依賴打包為單一 bundle 檔案，輸出至 `tui/dist/`。依賴版本 MUST 以同一批次的 `@opentui/core` 與 `@opentui/solid` 為準，且 `solid-js` MUST 對齊該批次 `@opentui/solid` 的 peer expectation，以降低未來 API 漂移與 peer mismatch 風險。產出的 bundle MUST NOT 同時內含多份版本不同的 OpenTUI core，且應用程式層不得因直接額外匯入 `@opentui/core` 而重新引入第二份 core module graph。

#### Scenario: 執行 build 產出 bundle
- **WHEN** 開發者在 `tui/` 目錄執行 `bun run build`
- **THEN** 系統 MUST 在 `tui/dist/` 產出可由 `bun` 直接執行的 JS bundle 檔案

#### Scenario: bundle 不得同時包含多份 OpenTUI core
- **WHEN** build 完成後檢視產出的 `tui/dist/index.js`
- **THEN** bundle 中 MUST 僅包含一份 OpenTUI core 的 env registry / renderer 初始化路徑
- **AND** 不得因兩份不同版本 core 重複註冊 `OTUI_DUMP_CAPTURES` 等全域 env var 而在啟動時崩潰

### Requirement: Build MUST 將 native .so 作為外部檔案處理
OpenTUI native binding MUST 不被 bundler inline，MUST 作為外部檔案複製至產出目錄。Build script MUST 將同批次 OpenTUI 發布的 supported native optional packages 列為 external，包括 glibc 與 musl Linux variants，並依目前平台與架構建立可解析 native library 的 shim。

#### Scenario: Bundle 不包含 native library 且 native library 存在於產出目錄
- **WHEN** build 完成後檢視 `tui/dist/`
- **THEN** 目錄 MUST 包含目前平台對應的 OpenTUI native library，且 JS bundle 中 MUST 不含 embedded binary data

#### Scenario: 升級後 native package shim 仍可解析
- **WHEN** `@opentui/core` 升級後完成 build
- **THEN** `dist/node_modules/@opentui/core-<platform>-<arch>/index.ts` MUST 仍可正確指向同目錄下的 native library，並使 bundle 啟動時可載入成功

#### Scenario: OpenTUI native package variants 保持 external
- **WHEN** OpenTUI 發布同批次 supported native optional packages
- **THEN** build script MUST 將這些 native package names 保持為 external
- **AND** bundler MUST NOT 嘗試將任何 OpenTUI native package inline 進 JS bundle

### Requirement: Bundle 產物 MUST 可獨立執行
產出的 bundle + `libopentui.so` MUST 可在不依賴 `node_modules` 的情況下由 `bun` 正確執行。

#### Scenario: 無 node_modules 環境下執行 bundle
- **WHEN** 將 `tui/dist/` 複製到不含 `node_modules` 的獨立目錄並以 `bun` 執行
- **THEN** 程式 MUST 正常啟動並渲染 TUI 畫面

#### Scenario: 打包後 runtime 啟動不因重複 env registry 崩潰
- **WHEN** 使用 TUI build 產物建出的 AppImage 或等效 runtime 執行入口啟動 TUI
- **THEN** 程式 MUST 正常啟動
- **AND** MUST NOT 因 OpenTUI env registry duplicate registration error 而在初始化階段退出
