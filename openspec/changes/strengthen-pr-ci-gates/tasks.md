## 1. Path-aware Change Detection

- [x] 1.1 建立不依賴第三方 action 的共用 change-detection script，以 base/head SHA 與平台 relevant paths輸出是否需執行heavy job
- [x] 1.2 讓detector在缺少SHA、無法取得完整diff或git失敗時fail closed，不得回報可安全略過
- [x] 1.3 新增detector tests，涵蓋core/TUI、Linux packaging、macOS packaging、tag workflow、docs-only與偵測失敗案例

## 2. Linux PR Validation Gate

- [x] 2.1 重構`appimage-dry-run.yml`，使每個目標為`main`的PR都建立detector與穩定的`appimage-required` final job
- [x] 2.2 將core、TUI、AppImage packaging、Linux dry-run與tag-driven release workflow納入Linux relevant paths
- [x] 2.3 在Linux heavy job加入`zig build test`與完整Bun test suite，再執行既有AppImage build/package/verify與artifact upload
- [x] 2.4 實作`if: always()` Linux final gate，只接受detector成功且heavy job成功或被正確略過
- [x] 2.5 加入以workflow及PR number區分的concurrency group並取消同一PR的過時run

## 3. macOS PR Validation Gate

- [x] 3.1 重構`macos-dry-run.yml`，使每個目標為`main`的PR都建立detector與穩定的`macos-required` final job
- [x] 3.2 將core、TUI、macOS packaging、macOS dry-run與tag-driven release workflow納入macOS relevant paths
- [x] 3.3 維持macOS heavy job的Zig/TUI tests、package/verify、native dylib/IPC smoke與failure diagnostics
- [x] 3.4 實作`if: always()` macOS final gate，只接受detector成功且heavy job成功或被正確略過
- [x] 3.5 加入以workflow及PR number區分的concurrency group並取消同一PR的過時run

## 4. Workflow Verification

- [x] 4.1 執行detector tests、Zig tests、TUI tests與兩平台現有本機可執行的package/regression checks
- [x] 4.2 驗證所有workflow YAML、shell syntax、permissions與required final job names，確認PR workflows沒有`contents: write`
- [x] 4.3 驗證docs-only時heavy jobs可略過但final gates存在，且core/TUI或tag workflow變更時兩平台heavy jobs都必須執行
- [x] 4.4 執行`openspec validate strengthen-pr-ci-gates --strict`並修正所有錯誤

## 5. Branch Protection Runbook

- [x] 5.1 新增CI merge-gate文件，記錄固定required contexts、bootstrap順序、approval count 0、strict up-to-date與rollback程序
- [x] 5.2 記錄設定前GitHub `main` protection/ruleset狀態與唯讀查詢命令
- [x] 5.3 文件化job更名前先遷移required contexts的操作順序，避免PR永久pending

## 6. GitHub Bootstrap 與 Enforcement

- [ ] 6.1 在使用者授權publish後，commit/push feature branch並建立PR，使新的final check contexts首次註冊
- [ ] 6.2 等待並確認`AppImage Dry Run / appimage-required`與`macOS Dry Run / macos-required`均在GitHub出現且成功
- [ ] 6.3 在取得使用者對外部設定變更的明確授權後，為`main`啟用require pull request、兩個required contexts、strict up-to-date、admin enforcement、無bypass actor與0 required approvals
- [ ] 6.4 透過GitHub API與PR mergeability狀態驗證缺失/失敗/過期checks會阻止merge，綠燈且最新branch可正常merge
- [ ] 6.5 記錄套用後protection設定與rollback命令，並確認未授予PR workflows額外write permission
