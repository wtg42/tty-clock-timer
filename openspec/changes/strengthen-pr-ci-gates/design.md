## Context

遠端 repository 的 `main` 目前沒有 branch protection 或 ruleset，GitHub 只存在 AppImage PR dry-run 與 tag release workflow。`add-macos-support` 在同一 worktree 新增 macOS dry-run，但尚未推送，因此 required check identity 尚未在 GitHub 註冊。現有 Linux PR workflow 有 top-level `paths`，且只做 build/package/verify；若直接把帶有 path filter 的 workflow 設為 required，未觸發的文件 PR 可能缺少 check context 而無法合併。

本 change 依賴 `add-macos-support` 的 macOS workflow，必須先完成 workflow code、推送 feature branch 並讓 checks 至少執行一次，之後才可安全設定 repository merge gate。

## Goals / Non-Goals

**Goals:**

- 在 Ubuntu 與 macOS arm64 對相關 PR 執行 Zig、TUI 及平台 packaging tests。
- 讓每個目標為 `main` 的 PR 都產生穩定且可設為 required 的 Linux/macOS final check contexts。
- 保留 path-aware heavy-job skipping，避免文件或無關路徑變更消耗 AppImage/macOS packaging runner。
- 啟用 `main` 的 PR-only、required checks 與 strict up-to-date merge policy。
- 提供可驗證、可回復的 repository settings 操作流程。

**Non-Goals:**

- 強制至少一位外部 reviewer 核准；目前是單一維護者 repository，approval count 保持 0。
- 改變 tag-driven release asset、版本或 publish 行為。
- 引入第三方 path-filter action、測試框架或程式 dependency。
- 自動合併 PR、繞過失敗 checks，或授予 workflow 額外 write permission。

## Decisions

### 1. Workflow 永遠建立 final gate，heavy jobs 採 path-aware conditional

兩個 PR workflows MUST 對所有指向 `main` 的 PR 事件啟動，不在 workflow `on.pull_request.paths` 層完全略過。每個 workflow 使用輕量 change-detection job（`actions/checkout` 搭配完整 history 與 `git diff`）判斷相關路徑，再條件式執行平台 heavy job；最後以 `if: always()` 的 final gate 彙整結果。

Linux relevant paths 包含 core、TUI、AppImage packaging、Linux dry-run 與 tag-driven release workflow。macOS relevant paths 包含 core、TUI、macOS packaging、macOS dry-run 與 tag-driven release workflow。文件或其他不相關變更可略過 heavy job，但 final gate 仍 MUST 成功回報「不需平台驗證」。

替代方案是直接 required 現有 heavy job 並保留 top-level `paths`；check context 可能完全不存在而阻塞 merge，因此不採用。另一方案是每個 PR 無條件跑兩平台完整 package，較簡單但浪費 macOS runner，因此不採用。

### 2. 不增加第三方 path-filter action

change detection 使用 GitHub event 的 base SHA/head SHA 與原生 `git diff --name-only`，並以 repository 內 shell 邏輯比對路徑。這避免新增 supply-chain surface；`actions/checkout` 必須使用足夠 history，且偵測失敗時 MUST fail closed，而不是把相關變更判成可略過。

### 3. Linux heavy job補齊 unit/integration tests

Linux job在 package 前依序執行 locked dependency install、`zig build test`、完整 `bun test --preload @opentui/solid/preload`，再執行 AppImage build/package/verify。任一步驟失敗都使 Linux final gate 失敗。macOS heavy job維持相同 core/TUI tests，並執行 package、native dylib/IPC smoke 與 failure diagnostics。

### 4. Required contexts 只綁穩定 final job names

workflow 與 final job的 `name` MUST 固定，例如：

- REST context `appimage-required`（GitHub UI所屬workflow：`AppImage Dry Run`）
- REST context `macos-required`（GitHub UI所屬workflow：`macOS Dry Run`）

Branch protection只 required這兩個 final job contexts，不直接綁會被條件略過的 heavy jobs，也不綁容易因 step 文案變動的名稱。PR #3已實測Checks API以job name註冊context。未來更名前 MUST 先遷移 repository settings，避免所有 PR 卡住。

### 5. Branch protection 分 bootstrap 與 enforcement

套用順序：

1. 將 workflows 推送到 feature branch並建立 PR。
2. 確認兩個 final checks 至少在 GitHub 出現一次且成功。
3. 以 repository admin 權限啟用 `main` protection：require pull request、require兩個 final contexts、strict up-to-date、`enforce_admins: true`；required approving reviews 設為 0，且不設定 bypass actor。
4. 重新同步 PR 並確認保護規則實際阻止失敗或過期 branch。

Repository settings 是外部 state；apply 階段修改前 MUST 取得使用者明確授權，並在 tasks/verification 文件記錄實際 contexts 與查詢結果。

### 6. 同一 PR concurrency

每個 PR workflow使用由 workflow 名稱與 PR number 組成的 concurrency group，`cancel-in-progress: true`。這只取消同一 PR 的舊 commit run，不得讓最新 commit略過驗證。

## Risks / Trade-offs

- Required context 尚未註冊就啟用 protection → 先推送並完成一次 checks，再設定 protection。
- Path detection 漏判會錯誤略過 heavy tests → fetch完整 history、fail closed，並以 workflow-only、core/TUI、各平台 packaging、docs-only案例驗證。
- Conditional heavy job 的 `skipped` 結果傳播不當 → final gate使用 `always()` 明確檢查 detector 與 heavy result，只接受 `success` 或經判定的不相關 `skipped`。
- Strict up-to-date 增加 PR 更新頻率 → concurrency取消過時 runs，確保只保留最新 commit驗證。
- 單人 repository 啟用 review approval會自鎖 → require PR但 approval count維持 0，只以 CI作 merge gate。
- Repository owner可用admin權限繞過checks → 啟用admin enforcement且不設定bypass actor，緊急狀況依runbook暫時調整protection而非隱性繞過。
- 外部 branch protection 無法由 Git history還原 → 記錄設定前狀態與回復命令；緊急 rollback時移除 required contexts或 protection。

## Migration Plan

1. 更新兩個 PR workflows 的 detector、heavy jobs、tests、final gates 與 concurrency。
2. 以本機 YAML/shell 檢查及現有測試驗證 workflow內容。
3. 推送 branch並建立 PR，觀察兩個 final check identity。
4. 在使用者明確授權後設定 `main` branch protection。
5. 以最新 PR commit驗證綠燈可合併、模擬失敗/過期狀態不可合併。

Rollback 時先移除 required contexts或暫時停用 protection，再回復 workflow；不得先刪除/更名 required job而留下無法滿足的 check context。

## Open Questions

- 若未來增加協作者，再另開 change決定 required approving review count與 CODEOWNERS。
- 是否將 branch protection改用 organization ruleset管理，待 repository管理需求擴大後評估。
