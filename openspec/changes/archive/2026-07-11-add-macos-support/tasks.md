## 1. macOS 原生相容性基線

- [x] 1.1 在 macOS arm64 安裝鎖定的 TUI dependencies，執行現有 Zig core 與 Bun TUI tests，記錄並修正平台相容失敗
- [x] 1.2 在 macOS arm64 執行 TUI production build，驗證 `libopentui.dylib` 與 `@opentui/core-darwin-arm64` shim 產出及載入
- [x] 1.3 新增 macOS arm64 build/test 的自動化檢查，並確認 Zig 平台處理只使用 `std`

## 2. Core 跨平台行為

- [x] 2.1 重構 socket path 產生邏輯，使其依序嘗試有效 `TMPDIR` 與 `/tmp`，且每個實例維持隨機唯一後綴
- [x] 2.2 新增 socket path 測試，涵蓋有效 `TMPDIR`、空值、過長 path fallback、多實例唯一性與結束清理
- [x] 2.3 將 `afplay` 加入 `--setup-sound` player detection，維持完整執行檔路徑與既有 config schema
- [x] 2.4 新增或更新 sound setup tests，驗證 `afplay` 被列出、可選取，且不影響既有 Linux players

## 3. macOS Runtime 與 Packaging

- [x] 3.1 建立 `packaging/macos/` 的 artifact contract 與目錄規格，對齊 `bin/ttc` launcher、`libexec` core 和 TUI runtime layout
- [x] 3.2 實作 macOS arm64 core/TUI build 與 stage scripts，驗證平台和 architecture 並拒絕錯誤 target
- [x] 3.3 實作可搬移的 `bin/ttc` launcher，解析自身 archive root、檢查 Bun prerequisite、注入 TUI/prompt helper contract 後 `exec` core
- [x] 3.4 實作版本化 tarball 與 SHA-256 checksum packaging script，確保輸出為 `tty-clock-timer-<version>-macos-arm64.tar.gz`
- [x] 3.5 實作 artifact verification script，檢查權限、core、bundle、prompt helper、`libopentui.dylib`、Darwin shim、版本命名與 checksum
- [x] 3.6 實作 packaged runtime smoke test，從 archive 外的 working directory 驗證 launcher、native library 載入、Unix socket IPC 與受控退出
- [x] 3.7 新增 packaging failure tests，涵蓋 Bun 或任一必要 artifact 缺失時的非零退出與可診斷訊息

## 4. CI 與 Release

- [x] 4.1 新增 macOS arm64 PR/manual dry-run workflow，在相關 core、TUI、macOS packaging 或 workflow path 變更時執行 build、tests、package、verify 與 smoke test
- [x] 4.2 設定 macOS dry-run 僅上傳 `.tar.gz` 與 checksum 為 Actions artifact，且不授予 GitHub Release 寫入權限
- [x] 4.3 將 tag-driven release 拆分為 Linux 與 macOS build jobs，並讓單一 publish job 只在兩平台 package/verify 都成功後執行
- [x] 4.4 讓 publish job 將 Linux AppImage、macOS arm64 tarball 與各自 checksum 發佈至同一 tag 對應的 GitHub Release
- [x] 4.5 驗證 Linux AppImage dry-run 與既有 package/verify scripts 在 workflow 調整後仍完整通過

## 5. 文件與最終驗證

- [x] 5.1 更新 Core–TUI artifact contract，文件化 Linux `.so` 與 macOS `.dylib` layout、launcher boundary 和 Bun prerequisite
- [x] 5.2 更新 README 與 packaging 文件，加入 Apple Silicon 支援範圍、checksum、解壓啟動步驟、完整目錄要求及常見錯誤排查
- [x] 5.3 文件化未 codesign/notarize 的 Gatekeeper/quarantine 限制，且不宣稱 Intel Mac、Universal Binary 或 self-contained runtime 已受支援
- [x] 5.4 執行 Zig tests、TUI tests/build、macOS package/verify/smoke test 與 Linux regression checks
- [x] 5.5 執行 `openspec validate add-macos-support --strict` 並修正所有驗證錯誤
