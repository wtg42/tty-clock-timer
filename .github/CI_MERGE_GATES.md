# CI Merge Gates

此文件記錄 `main` 的跨平台 CI merge gate、bootstrap、驗證與 rollback。Repository 是單一維護者模式，因此 required approving reviews 設為 `0`；Linux與macOS checks仍必須成功，且規則套用至repository admins。

## Stable Required Checks

Workflow與final job名稱不得任意變更：

| Workflow | Final job | GitHub UI預期context |
| --- | --- | --- |
| `AppImage Dry Run` | `appimage-required` | `AppImage Dry Run / appimage-required` |
| `macOS Dry Run` | `macos-required` | `macOS Dry Run / macos-required` |

設定branch protection前，必須以實際PR的`gh pr checks`或Checks API確認GitHub註冊的context字串；REST API的required context值以GitHub實際回傳為準，不得只猜測UI顯示名稱。

兩個workflows會在每個目標為`main`的PR建立final job。Detector依路徑決定是否執行heavy platform job；docs-only可略過heavy job，但final gate仍會出現。

## Pre-change Snapshot (2026-07-10)

套用本change前的唯讀查詢結果：

- `main` branch protection：未啟用（REST API回傳HTTP 404 `Branch not protected`）
- Repository rulesets：空陣列
- Required status checks：無

重新查詢：

```bash
gh api repos/wtg42/tty-clock-timer/branches/main/protection
gh api repos/wtg42/tty-clock-timer/rulesets
gh workflow list --repo wtg42/tty-clock-timer --all
```

## Bootstrap Order

1. Commit並push包含兩個final jobs的feature branch。
2. 建立目標為`main`的PR。
3. 等待`appimage-required`與`macos-required`至少成功一次。
4. 以`gh pr checks <pr-number> --repo wtg42/tty-clock-timer`記錄實際check names。
5. 取得使用者對GitHub repository設定變更的明確授權。
6. 對`main`套用branch protection：
   - require pull request
   - required approving review count：`0`
   - required Linux/macOS final contexts
   - strict up-to-date：`true`
   - enforce admins：`true`
   - bypass actors：無
   - force push與branch deletion：停用
7. 再次查詢protection並檢查PR mergeability。

不得在final contexts成功出現前先設定required checks，否則PR可能永久等待不存在的context。

## Protection Payload Shape

實際context值確認後，以GitHub Branch Protection API套用等價於下列設定：

```json
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["<actual-linux-context>", "<actual-macos-context>"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 0,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": false,
  "lock_branch": false
}
```

套用前保存目前API回應；外部設定變更必須由使用者明確授權。

## Verification

```bash
gh api repos/wtg42/tty-clock-timer/branches/main/protection
gh pr checks <pr-number> --repo wtg42/tty-clock-timer
gh pr view <pr-number> --repo wtg42/tty-clock-timer --json mergeable,mergeStateStatus,statusCheckRollup
```

驗證條件：

- 任一required check失敗、缺失或進行中時不可正常merge。
- PR branch落後`main`時必須先同步並重新執行checks。
- 兩個checks成功且branch最新時可正常merge。
- PR workflows維持`contents: read`，不得因required gate取得write permission。

## Renaming a Required Job

不可先刪除或更名舊job。安全順序：

1. 暫時同時提供舊、新final jobs。
2. Push並讓新context在PR成功出現。
3. 將branch protection從舊context切換至新context。
4. 驗證merge gate後才移除舊job。

## Rollback

若workflow或context設定造成所有PR阻塞：

1. 以API保存當前protection回應與失敗checks。
2. 暫時從required contexts移除有問題的context，或在必要時移除branch protection。
3. 修復workflow並讓context重新成功出現。
4. 重新啟用strict required checks與admin enforcement。

Rollback不得使用force push、直接修改`main`或保留永久admin bypass作為正常流程。
