## MODIFIED Requirements

### Requirement: Failure signaling for release stages
系統 MUST 在建置、封裝或上傳任一階段失敗時回報明確失敗狀態，讓維護者可識別失敗階段並採取 fallback。tag-driven release workflow MUST 在打包前新增工具準備階段，透過專案內共用腳本下載 Linux x86_64 `gum` 至 `packaging/tools/gum/linux-x64/gum`，並 MUST 驗證固定版本對應的 checksum；若下載或校驗失敗，workflow MUST 於工具準備階段明確失敗，不得進入後續打包階段。

#### Scenario: 失敗時可判讀階段
- **WHEN** tag-driven release 在任一關鍵階段失敗
- **THEN** workflow MUST 回報失敗且指出失敗階段（建置、封裝或上傳）

#### Scenario: 工具準備失敗時中止 release
- **WHEN** workflow 在 `gum` 下載或 checksum 驗證失敗
- **THEN** workflow MUST 以工具準備階段失敗結束
- **AND** workflow MUST NOT 繼續執行 AppImage 打包與上傳
