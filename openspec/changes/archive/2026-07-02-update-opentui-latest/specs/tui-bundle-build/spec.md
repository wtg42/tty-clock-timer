## MODIFIED Requirements

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
