## Context

專案目前以 Zig core 啟動 Bun/OpenTUI TUI，兩者透過 Unix Domain Socket 通訊；Linux release 則以 AppImage wrapper 注入 TUI runtime 路徑。OpenTUI lockfile 與 build config 已包含 Darwin arm64 native package 及 `libopentui.dylib` 命名，但尚未建立 macOS runtime layout、驗證腳本或 CI release job。此次變更跨越 core、TUI、packaging、CI 與文件，同時受到僅使用 Zig `std`、維持 core 掌管 TUI lifecycle，以及不干擾既有 Linux AppImage 的限制。

## Goals / Non-Goals

**Goals:**

- 在 macOS arm64 原生 runner 建置並測試 Zig core 與 Bun/OpenTUI TUI。
- 產出可搬移、版本化且可驗證的 macOS arm64 `.tar.gz`。
- 讓 package launcher 只負責解析自身位置與注入 runtime contract，UI 仍由 core 啟動。
- 支援 `afplay`，並讓 Unix socket path 在 macOS 暫存目錄語意與長度限制下安全運作。
- 讓同一版本 tag 的 GitHub Release 同時包含既有 Linux AppImage 與 macOS artifact。

**Non-Goals:**

- Intel Mac、Universal Binary、Homebrew formula、`.app` 或 `.pkg`。
- 封裝 Bun runtime、移除使用者對 Bun 的 prerequisite。
- Apple Developer ID codesign、notarization 或自動處理 quarantine attribute。
- 將 config/history 搬遷至 `~/Library/Application Support`。
- 引入第三方 Zig package或改寫 IPC 架構。

## Decisions

### 1. 首版只在 macOS arm64 原生建置

macOS package MUST 在 macOS arm64 runner 原生執行 Zig、Bun 與 OpenTUI build，並納入 `@opentui/core-darwin-arm64` 的 `libopentui.dylib`。這比從 Linux cross-compile 更能驗證 native library 載入、terminal、process spawn 與 Unix socket 行為。

替代方案是同時產出 x86_64 或 Universal Binary；這會增加 native library 合併、雙架構測試及簽章複雜度，因此延後處理。

### 2. 使用可搬移 tarball 與薄 launcher

archive 解壓後採用下列 layout：

```text
tty-clock-timer-<version>-macos-arm64/
├── bin/ttc                         # 薄 launcher
├── libexec/tty-clock-timer/ttc     # Zig core
└── lib/tty-clock-timer/tui/
    ├── index.js
    ├── prompts/helper.js
    ├── libopentui.dylib
    └── node_modules/@opentui/core-darwin-arm64/index.ts
```

launcher 根據自身所在位置設定 `TTY_CLOCK_TUI_CWD`、`TTY_CLOCK_TUI_ENTRY` 與 prompt helper entry，再以 `exec` 轉交 Zig core。launcher 不直接啟動 TUI，因此不改變 core 的 lifecycle ownership。相較於要求使用者手動設定環境變數，此方式可搬移且較不易誤用；相較於立即修改 core 做 executable-relative discovery，則能降低首版 core 路徑解析風險。

### 3. Bun 維持外部 prerequisite

package 不內含 Bun，launcher 與 verify 流程 MUST 明確檢查 `bun` 可從 `PATH` 執行，README 也 MUST 說明安裝前提。這延續目前 core 的 `bun run` contract，避免本次同時處理 runtime redistribution、更新與簽章。

### 4. Socket 暫存目錄採候選與長度驗證

core 優先嘗試非空且可用的 `TMPDIR`，再 fallback `/tmp`。每個候選都使用隨機實例後綴；完整路徑必須能通過 `std.Io.net.UnixAddress.init`，過長或無法使用時才嘗試下一候選。所有實例在結束時維持既有安全清理行為。此方案使用 Zig `std`，不增加平台 package。

替代方案是永遠使用 `/tmp`；雖然可在 macOS 運作，但沒有利用系統提供的 per-user temp directory。另一方案是截斷 `TMPDIR`，但可能產生不透明或碰撞風險，因此不採用。

### 5. `afplay` 沿用外部 player contract

在既有 player detection 順序中加入 `afplay`，保存解析後的完整路徑，播放時仍由 TUI 以 `Bun.spawn([player, file])` 執行。這不需要 audio library，也不改變 config schema。

### 6. Release 以平台 build jobs 與單一 publish 階段協調

tag workflow 將 Linux 與 macOS 建置產物分開產生、分別驗證，再由依賴兩者成功的 publish 階段建立或更新同一 GitHub Release。PR/dry-run 路徑只上傳 Actions artifact，不建立 Release。這避免兩個獨立 workflow 同時建立同一 release 的 race condition。

## Risks / Trade-offs

- 未 codesign/notarize 的下載產物可能被 Gatekeeper 或 quarantine 阻擋 → README 明確標示限制與安全驗證方式；正式簽章另開 change。
- macOS `TMPDIR` 可能超過 Unix socket path 上限 → 在 bind 前驗證完整路徑並 fallback `/tmp`，加入長路徑測試。
- 使用者未安裝 Bun或 Bun 不在非互動 shell 的 `PATH` → launcher/verify 及文件提供清楚診斷，不靜默 fallback。
- tag workflow 重構可能回歸 Linux AppImage release → 保留 Linux package/verify scripts，兩平台 dry-run 均成功後 publish。
- tarball 可搬移但使用者若只複製 `bin/ttc` 會破壞相對 layout → launcher 在 runtime 缺失時輸出可理解錯誤，文件要求保留整個解壓目錄。

## Migration Plan

1. 先在 macOS arm64 驗證現有 core/TUI tests 與 native OpenTUI build。
2. 完成 socket 與 `afplay` 的跨平台行為及測試。
3. 建立 macOS stage/package/verify/smoke scripts，產出 dry-run artifact。
4. 將 release workflow 調整為 Linux/macOS build jobs 與共同 publish 階段。
5. 更新文件後，以 prerelease tag 驗證兩平台資產，再啟用正式 tag release。

Rollback 時可移除 macOS job 與 asset，既有 Linux scripts 與 AppImage runtime contract維持可獨立運作；core 的 `TMPDIR` fallback 與 `afplay` 偵測為向後相容變更。

## Open Questions

- 正式 codesign/notarization 所需的 Apple Developer ID 與 secrets 由後續 change 決定。
- Intel Mac 的需求量與 GitHub runner 可用性待 arm64 MVP 發佈後再評估。

