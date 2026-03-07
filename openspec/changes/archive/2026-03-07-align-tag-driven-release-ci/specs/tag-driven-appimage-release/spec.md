## MODIFIED Requirements

### Requirement: Failure signaling for release stages
系統 MUST 在建置、封裝或上傳任一階段失敗時回報明確失敗狀態，讓維護者可識別失敗階段並採取 fallback。tag-driven release workflow MUST 在打包前完成 Zig/Bun 環境準備、TUI 相依安裝與 `appimagetool` 準備；Linux x86_64 AppImage 所需的 prompt helper artifact MUST 由既有 packaging/build 流程產生，並由 package/verify 腳本檢查，不得再依賴獨立的 `gum` 下載/checksum 階段。

#### Scenario: 失敗時可判讀階段
- **WHEN** tag-driven release 在任一關鍵階段失敗
- **THEN** workflow MUST 回報失敗且指出失敗階段（建置、封裝、驗證或上傳）

#### Scenario: TUI 依賴安裝失敗時中止 release
- **WHEN** workflow 在 Bun setup 或 `bun install --frozen-lockfile` 失敗
- **THEN** workflow MUST 以失敗狀態結束
- **AND** workflow MUST NOT 繼續執行 AppImage 打包與上傳

#### Scenario: prompt helper artifact 缺失時中止 release
- **WHEN** packaging/build 流程未能產出或 verify 未能找到 `prompts/helper.js`
- **THEN** workflow MUST 於 package 或 verify 階段明確失敗
- **AND** workflow MUST NOT 繼續執行後續 release upload
