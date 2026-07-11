## ADDED Requirements

### Requirement: PR 必須產生穩定的跨平台 final checks
系統 MUST 對每個目標為 `main` 的 pull request建立穩定的 Linux與macOS final check contexts。平台 heavy job MAY 依變更路徑略過，但 workflow MUST 仍產生 final check；final check MUST 只在 detector成功，且 heavy job成功或被正確判定為不相關而略過時成功。Required final job identity MUST 保持穩定，任何更名 MUST 先與 repository protection設定協調遷移。

#### Scenario: Core 或 TUI 變更
- **WHEN** PR變更包含 `core/**` 或 `tui/**`
- **THEN** Linux與macOS heavy jobs MUST 執行
- **AND** 兩個 final checks MUST 反映各自 heavy job結果

#### Scenario: 單一平台 packaging 變更
- **WHEN** PR只變更其中一個平台的 packaging路徑
- **THEN** 對應平台 heavy job MUST 執行
- **AND** 另一平台 MAY 略過 heavy job，但其 final check MUST 成功回報不需驗證

#### Scenario: 文件或無關路徑變更
- **WHEN** PR不包含任一平台 relevant path
- **THEN** 平台 heavy jobs MAY 略過
- **AND** Linux與macOS final checks MUST 仍出現且不得永久停留在 expected/pending

#### Scenario: 變更偵測失敗
- **WHEN** workflow無法取得完整比較範圍或 path detector執行失敗
- **THEN** final check MUST 失敗
- **AND** workflow MUST NOT 將該PR判定為可安全略過heavy tests

### Requirement: 相關 PR 必須完成兩平台測試與封裝驗證
Linux heavy job MUST 在 Ubuntu runner執行 `zig build test`、完整 Bun test suite、AppImage build/package/verify；macOS heavy job MUST 在Apple Silicon runner執行 Zig tests、完整 Bun test suite、macOS package/verify、native dylib/IPC smoke及packaging failure diagnostics。任一必要步驟失敗 MUST 傳播為對應 final check失敗。

#### Scenario: Linux unit test失敗
- **WHEN** Ubuntu runner上的 Zig或Bun tests失敗
- **THEN** Linux heavy job與final check MUST 失敗
- **AND** AppImage產物不得被視為可合併驗證成功

#### Scenario: macOS smoke test失敗
- **WHEN** macOS native dylib、Unix socket IPC或controlled quit smoke失敗
- **THEN** macOS heavy job與final check MUST 失敗

#### Scenario: 兩平台驗證成功
- **WHEN** relevant PR的Linux與macOS tests、package及verify均成功
- **THEN** 兩個final checks MUST 回報成功並可供branch protection判定

### Requirement: main 必須以 required checks保護合併
GitHub repository的 `main` branch MUST 要求透過pull request合併，MUST 將穩定的Linux與macOS final contexts設為required status checks，並 MUST 要求branch在合併前與最新`main`同步。Protection MUST 套用至repository admins且不得設定bypass actor。Required approving review count SHALL 為0，除非後續規格另行變更。失敗、缺失、進行中或過期的required checks MUST 阻止正常merge。

#### Scenario: Required checks全部成功且branch最新
- **WHEN** PR的兩個required final checks成功，且head包含最新`main`
- **THEN** branch protection MUST 允許具權限維護者正常合併

#### Scenario: 任一required check失敗或缺失
- **WHEN** Linux或macOS required final check失敗、缺失或仍在進行
- **THEN** branch protection MUST 阻止正常合併

#### Scenario: PR branch落後main
- **WHEN** required checks曾成功但PR head不再包含最新`main`
- **THEN** branch protection MUST 要求更新branch並重新驗證後才能合併

#### Scenario: Branch protection bootstrap
- **WHEN** required final contexts尚未在GitHub成功出現過
- **THEN** 維護者 MUST 先推送workflow並完成至少一次checks
- **AND** 系統 MUST NOT 提前設定無法被滿足的required context

#### Scenario: Repository admin嘗試略過required checks
- **WHEN** repository admin或owner的PR缺少成功的required final checks
- **THEN** branch protection MUST 同樣阻止正常merge
- **AND** repository MUST NOT 透過預設bypass actor規避此限制

### Requirement: PR workflow必須取消同一PR的過時執行
Linux與macOS PR workflows MUST 使用以workflow及PR識別碼區分的concurrency group，且 MUST 取消同一PR舊commit的進行中runs。不同PR或最新commit的run MUST NOT 被錯誤取消。

#### Scenario: 同一PR快速推送新commit
- **WHEN** 同一PR在舊workflow run完成前推送新commit
- **THEN** 舊run MUST 被取消
- **AND** 最新commit的run MUST 繼續並產生final check

#### Scenario: 不同PR同時執行
- **WHEN** 兩個不同PR同時觸發平台驗證
- **THEN** 兩者 MUST 使用不同concurrency groups且互不取消
