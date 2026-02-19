## Context

目前 `gum` lookup 主要以執行時工作目錄的相對路徑（`tools/gum/...`）與 PATH 為主，對本地開發可用，但對 AppImage runtime 不夠穩定。AppImage 的啟動路徑與使用者工作目錄可能不同，若未將 `gum` 作為 artifact 一起打包，`list` 互動體驗會在「有無系統安裝 gum」之間漂移，並頻繁退回 fallback。

此外，`gum` 是執行時工具，責任邊界更接近 packaging/runtime contract，而非 core 原始碼目錄資產。將 `gum` 放在 `core/` 外可避免核心程式與平台二進位資產耦合，並與現有 `packaging/tools` 管理方式一致。

## Goals / Non-Goals

**Goals:**
- 將 Linux x86_64 的 `gum` 納入 AppImage runtime artifact，確保發佈版可穩定使用。
- 在打包與驗證流程加入 `gum` 存在性與可執行性檢查，失敗時快速回報。
- 在 core 增加 AppImage 友善的 gum 解析優先順序，同時保留 fallback。
- 明確化 `gum` 原始資產放置位置，避免放在 `core/` 目錄下。

**Non-Goals:**
- 不處理 Linux arm64、macOS 或其他平台的 bundled gum 交付。
- 不改動 `gum choose` 互動參數或 fallback 選單行為語意。
- 不將 `gum` 變成 hard dependency（仍保留 PATH 與 fallback 路徑）。

## Decisions

### Decision 1: `gum` 原始資產改由 `packaging/tools` 管理

- 來源路徑採 `packaging/tools/gum/linux-x64/gum`。
- 理由：這是發佈工件（artifact）而非核心原始碼，應與 `appimagetool` 同層管理。

**Alternatives considered:**
- 保持 `tools/gum/...`：本地可用但責任邊界模糊，且與 AppImage 打包腳本關聯分散。
- 放在 `core/` 內：會把平台 binary 與核心程式碼耦合，不利維護。

### Decision 2: AppImage 打包時固定複製 gum 到 runtime tools 目錄

- AppDir 目標路徑：`usr/lib/tty-clock-timer/tools/gum/linux-x64/gum`。
- `package-appimage.sh` 在 copy 前先檢查來源檔存在且 executable，並在 AppDir 端再次確保 executable bit。

**Alternatives considered:**
- 只依賴 PATH：在乾淨環境不可預測，無法保證發佈品質。
- 將 gum 放在 `usr/bin`：可行，但會增加 PATH 汙染風險；此處選擇專用 runtime 私有路徑。

### Decision 3: 透過 AppRun 注入 `TTY_CLOCK_GUM_BIN`，core 優先使用

- AppRun 設定：`TTY_CLOCK_GUM_BIN=${APPDIR}/usr/lib/tty-clock-timer/tools/gum/linux-x64/gum`。
- core lookup 順序：
  1. `TTY_CLOCK_GUM_BIN`（若存在且可執行）
  2. 本地相對路徑候選（保留既有開發路徑）
  3. PATH `gum`
  4. fallback 純文字選單

**Alternatives considered:**
- core 直接硬編 APPDIR 路徑：與啟動器契約耦合較高，且降低覆寫彈性。
- 移除本地相對路徑：會破壞現有開發流程。

### Decision 4: verify 階段新增 gum artifact 驗證

- `verify-artifact.sh` 新增 AppDir gum 檢查（存在 + executable）。
- 理由：將缺檔問題前移到 CI/package 驗證階段，而非使用者執行期才發現。

## Risks / Trade-offs

- **[平台限制]** 僅納入 linux-x64，其他平台仍依賴 PATH/fallback → 以「僅 AppImage 目標平台保證」清楚定義範圍。
- **[資產同步]** 路徑搬遷後可能與舊文件/腳本不一致 → 同步更新 release 文件與腳本常數。
- **[可執行位元遺失]** 版本管理或下載可能移除 executable bit → package 與 verify 皆加入檢查與修正。
- **[env 覆寫風險]** 使用者可覆寫 `TTY_CLOCK_GUM_BIN` 指到無效路徑 → core 保留失敗即 fallback，避免功能中斷。

## Migration Plan

1. 建立/確認 `packaging/tools/gum/linux-x64/gum` 作為唯一 Linux x64 來源。
2. 更新 `package-appimage.sh`：加入 precheck、copy 到 AppDir、注入 `TTY_CLOCK_GUM_BIN`。
3. 更新 `verify-artifact.sh`：加入 AppDir gum 檢查。
4. 更新 core gum lookup：支援 `TTY_CLOCK_GUM_BIN` 並保留既有 fallback。
5. 更新 `packaging/appimage/release.md`：補充 gum preflight 與驗證項。

Rollback strategy:
- 若新路徑整合造成問題，可回退為 PATH + fallback 模式；功能仍可用但互動品質降低。

## Open Questions

- 是否需要在 CI 額外加入 smoke test，驗證 AppImage 中 `list` 實際走 `gum` 而非 fallback？
- 後續若擴充其他平台，是否沿用同一 runtime tools 目錄結構（`tools/gum/<platform>/gum`）？
