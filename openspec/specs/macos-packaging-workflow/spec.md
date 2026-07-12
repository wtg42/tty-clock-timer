# macos-packaging-workflow Specification

## Purpose
TBD - created by archiving change add-macos-support. Update Purpose after archive.
## Requirements
### Requirement: macOS arm64 runtime artifact 必須可搬移且完整
系統 MUST 在 macOS arm64 原生環境產出版本化 `.tar.gz`，其解壓目錄 MUST 包含 `bin/ttc` launcher、Zig core、TUI bundle、prompt helper、`libopentui.dylib` 與 Darwin arm64 native package shim。launcher MUST 以自身位置解析 runtime artifact、注入 Core–TUI contract 後 `exec` core，且 MUST NOT 直接啟動 TUI。macOS MVP MUST 將可從 `PATH` 執行的 Bun 定義為 runtime prerequisite，且 MUST NOT 宣稱產物為 self-contained。

#### Scenario: 解壓後從任意工作目錄啟動
- **WHEN** 使用者保留完整解壓目錄、已安裝 Bun，並從任意 working directory 執行 `<archive-root>/bin/ttc --seconds 1`
- **THEN** launcher MUST 定位同一 archive root 下的 core 與 TUI artifacts
- **AND** TUI MUST 由 core 啟動，而非由 launcher 直接啟動

#### Scenario: 必要 runtime artifact 缺失
- **WHEN** package 中缺少 core、`index.js`、`prompts/helper.js`、`libopentui.dylib` 或 Darwin arm64 shim 任一必要 artifact
- **THEN** package verification MUST 失敗並指出缺失項目

#### Scenario: Bun prerequisite 不可用
- **WHEN** 使用者環境無法從 `PATH` 執行 Bun
- **THEN** launcher MUST 以非零 exit code 結束並輸出可理解的 prerequisite 訊息

### Requirement: macOS package 流程必須可重現驗證
系統 MUST 提供 macOS build、package 與 verify scripts，並以明確版本字串產出 `tty-clock-timer-<version>-macos-arm64.tar.gz` 及對應 SHA-256 checksum。流程 MUST 在 macOS arm64 原生環境建置 core 與 TUI，且 MUST 在任一建置、組裝或驗證階段失敗時以非零狀態結束。

#### Scenario: 成功建立版本化 package
- **WHEN** 維護者在具備受支援 Zig、Bun 與 dependencies 的 macOS arm64 環境執行 package 流程
- **THEN** 系統 MUST 產出命名含相同版本字串的 `.tar.gz` 與 checksum

#### Scenario: 載入 Darwin native library 的 smoke test
- **WHEN** package verification 對解壓後產物執行 smoke test
- **THEN** TUI runtime MUST 成功解析 `@opentui/core-darwin-arm64` shim 並載入 `libopentui.dylib`
- **AND** core 與 TUI MUST 能建立 Unix socket 連線並完成受控退出

### Requirement: macOS release 必須與版本 tag 對齊
系統 MUST 在符合版本規範的 Git tag release 流程中建置並驗證 macOS arm64 artifact，且只有 Linux AppImage 與 macOS artifact 都成功後，才 MUST 將兩者及各自 checksum 發佈至同一 GitHub Release。PR 或手動 dry-run MUST 上傳 macOS package 為 GitHub Actions artifact，且 MUST NOT 建立或更新 GitHub Release。

#### Scenario: Tag release 同時包含兩平台產物
- **WHEN** tag-driven Linux 與 macOS build、package、verify stages 全部成功
- **THEN** publish stage MUST 將 Linux AppImage 與 macOS arm64 `.tar.gz` 發佈到同一版本的 GitHub Release

#### Scenario: 任一平台驗證失敗
- **WHEN** Linux 或 macOS 的 package/verify stage 任一失敗
- **THEN** publish stage MUST NOT 發佈不完整的 release

#### Scenario: macOS dry-run
- **WHEN** 維護者手動觸發或相關 PR path 觸發 macOS dry-run
- **THEN** workflow MUST 在 macOS arm64 runner 完成 build、package、verify 與 smoke test
- **AND** workflow MUST 僅上傳 Actions artifact，不得建立 GitHub Release

### Requirement: macOS 安裝限制必須文件化
系統 MUST 文件化 Apple Silicon 支援範圍、Bun prerequisite、解壓與執行方式、checksum 驗證、完整目錄不可拆散，以及未 codesign/notarize 可能造成的 Gatekeeper/quarantine 限制。文件 MUST NOT 暗示 Intel Mac、Universal Binary 或 self-contained runtime 已受支援。

#### Scenario: 使用者查閱 macOS 安裝說明
- **WHEN** 使用者依 README 安裝 macOS artifact
- **THEN** 文件 MUST 提供可重現的下載後驗證、解壓與啟動步驟
- **AND** 文件 MUST 清楚列出 Bun 與未簽章產物限制
