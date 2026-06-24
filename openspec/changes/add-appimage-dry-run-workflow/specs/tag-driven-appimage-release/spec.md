## MODIFIED Requirements

### Requirement: Tag-driven release trigger
系統 MUST 在建立符合版本規範的 Git tag 時自動啟動 AppImage release 流程，且 MUST 將該 tag 作為本次 release 的唯一版本來源。系統 SHALL 另外提供手動觸發的 AppImage dry-run workflow，供維護者在不建立 Git tag、不建立 GitHub Release 的情況下驗證 Linux AppImage package/verify 流程。

#### Scenario: Tag 建立後自動啟動 release
- **WHEN** 維護者推送一個符合規範的版本 tag
- **THEN** CI MUST 自動啟動 AppImage release workflow，且流程版本 MUST 直接取自該 tag

#### Scenario: 手動啟動 AppImage dry-run
- **WHEN** 維護者透過 GitHub Actions 手動觸發 AppImage dry-run workflow
- **THEN** workflow MUST 在 Ubuntu runner 執行 AppImage build、package 與 verify
- **AND** workflow 的 core build stage MUST 能在 Zig master 下編譯出 `tic`
- **AND** workflow MUST NOT 建立或更新 GitHub Release
- **AND** workflow MUST NOT 需要 `contents: write` permission

### Requirement: Release artifacts align with tag version
系統 MUST 以 tag 版本產出 AppImage 檔名與 release metadata，並確保產物與 release 條目可由版本字串直接對應追溯。Dry-run workflow MUST 使用明確的 dry-run version 字串命名產物，並將產物保存為 GitHub Actions artifact 而非 release asset。

#### Scenario: 產物命名與 metadata 一致
- **WHEN** tag-driven workflow 完成打包與上傳
- **THEN** AppImage 檔名與 release metadata MUST 使用同一個 tag 版本字串

#### Scenario: Dry-run 產物可下載檢查
- **WHEN** AppImage dry-run workflow 完成 package 與 verify
- **THEN** workflow MUST 上傳 AppImage 產物為 GitHub Actions artifact
- **AND** artifact 名稱 MUST 明確包含 dry-run run number

### Requirement: Failure signaling for release stages
系統 MUST 在建置、封裝、驗證或上傳任一階段失敗時回報明確失敗狀態，讓維護者可識別失敗階段並採取 fallback。tag-driven release workflow MUST 在打包前完成 Zig/Bun 環境準備、TUI 相依安裝與 `appimagetool` 準備；Linux x86_64 AppImage 所需的 prompt helper artifact MUST 由既有 packaging/build 流程產生，並由 package/verify 腳本檢查，不得再依賴獨立的 `gum` 下載/checksum 階段。Dry-run workflow MUST 重用既有 packaging/build/verify scripts 並在任一階段失敗時以失敗狀態結束。Core build path MUST NOT 使用已從目前 Zig master 移除的 `std.Build.args` 或 `std.meta.fields` API。

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
- **AND** workflow MUST NOT 繼續執行 AppImage 打包與上傳

#### Scenario: Dry-run package or verify failure
- **WHEN** AppImage dry-run workflow 的 package 或 verify stage 失敗
- **THEN** workflow MUST 以失敗狀態結束
- **AND** workflow MUST NOT 建立 GitHub Release

#### Scenario: Dry-run core build uses current Zig master APIs
- **WHEN** AppImage dry-run workflow 執行 core build stage
- **THEN** build script MUST 使用目前 Zig master 支援的 run step passthrough argument API
- **AND** core source MUST NOT 使用已移除的 `std.meta.fields`
