# tui-bundle-build Specification

## Purpose
定義 TUI 的 bun build 流程，包含 Solid plugin 整合、external native binding 處理、產物規格。

## Requirements

### Requirement: TUI MUST 可透過 bun build 產出單一 JS bundle
系統 MUST 提供 build script（`tui/build.ts`），使用 `Bun.build()` 搭配 `@opentui/solid/bun-plugin` 將 `src/index.tsx` 及其所有 JS/TS 依賴打包為單一 bundle 檔案，輸出至 `tui/dist/`。依賴版本 MUST 為 `@opentui/core` 與 `@opentui/solid` v0.1.81 或以上。

#### Scenario: 執行 build 產出 bundle
- **WHEN** 開發者在 `tui/` 目錄執行 `bun run build`
- **THEN** 系統 MUST 在 `tui/dist/` 產出可由 `bun` 直接執行的 JS bundle 檔案

### Requirement: Build MUST 將 native .so 作為外部檔案處理
`@opentui/core-linux-x64/libopentui.so` 為 bun:ffi native binding，MUST 不被 bundler inline，MUST 作為外部檔案複製至產出目錄。

#### Scenario: Bundle 不包含 .so 且 .so 存在於產出目錄
- **WHEN** build 完成後檢視 `tui/dist/`
- **THEN** 目錄 MUST 包含 `libopentui.so`，且 JS bundle 中 MUST 不含 embedded binary data

### Requirement: Bundle 產物 MUST 可獨立執行
產出的 bundle + `libopentui.so` MUST 可在不依賴 `node_modules` 的情況下由 `bun` 正確執行。

#### Scenario: 無 node_modules 環境下執行 bundle
- **WHEN** 將 `tui/dist/` 複製到不含 `node_modules` 的獨立目錄並以 `bun` 執行
- **THEN** 程式 MUST 正常啟動並渲染 TUI 畫面
