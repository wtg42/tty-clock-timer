# AppImage Packaging Foundation

此目錄提供 Linux x86_64 的 AppImage 打包骨架，支援 `tty-clock-timer` 的 tag-driven 自動發版主流程與 manual release fallback。

## Target and Output

- Target platform: `linux-x86_64`
- AppImage output directory: `packaging/out/appimage/`
- AppImage file pattern: `tty-clock-timer-<version>-linux-x86_64.AppImage`

## Directory Layout

```text
packaging/appimage/
├── README.md
├── artifact-contract.md
├── checklist.md
├── release.md
├── verification.md
├── assets/
│   ├── tty-clock-timer.desktop
│   └── tty-clock-timer.svg
└── scripts/
    ├── build-core.sh              # 編譯 Zig Core 二進檔
    ├── fetch-gum.sh               # 下載並驗證 gum 工具
    ├── setup-deps.sh              # 防呆檢查：自動下載依賴
    ├── package-appimage.sh         # 打包 AppImage（已整合防呆流程）
    ├── verify-artifact.sh
    ├── mvp-smoke.ts
    └── timer-smoke.ts
```

## 防呆機制與依賴管理

### 自動依賴檢查（setup-deps.sh）

首次運行 `package-appimage.sh` 時，腳本會**自動執行** `setup-deps.sh` 進行依賴檢查與下載：

1. **gum 工具**：檢查 `packaging/tools/gum/linux-x64/gum` 是否存在
   - 若缺失 → 自動執行 `fetch-gum.sh` 下載 v0.17.0
   - 若已存在 → 跳過下載，提示已就緒

2. **appimagetool**：檢查以下優先順序
   - 環境變數 `APPIMAGETOOL_BIN`（使用者明確指定）
   - 本機路徑 `packaging/tools/appimagetool.AppImage`
   - 系統路徑（`command -v appimagetool`）
   - 若都不存在 → 自動下載最新版本（1.9.1）到本機路徑

3. **TUI 依賴**：檢查 `tui/node_modules` 是否存在
   - 若缺失 → 自動執行 `bun install`（需要 bun 已安裝）
   - 若已存在 → 跳過安裝，提示已就緒

### 增量構建

`package-appimage.sh` 採用 **repo-local clean rebuild** 策略：每次執行都會先清理以下路徑，再重建 core 與 TUI。

- `packaging/out/appimage/stage`
- `packaging/out/appimage/AppDir`
- `core/zig-out`
- `core/.zig-cache`
- `tui/dist`

此策略不會清除全域 cache（例如 Bun 全域快取），但會增加單次打包時間，以換取跨機器與跨分支的一致產物。

### 常見問題與解決方案

#### ❌ appimagetool 下載失敗（404）

**原因**：版本號過時或網路連接失敗

**解決**：
```bash
# 方式 1：手動指定最新版本
export APPIMAGETOOL_BIN=/path/to/your/appimagetool
APPIMAGE_VERSION=1.0.0 ./packaging/appimage/scripts/package-appimage.sh

# 方式 2：從 GitHub 下載最新版本
mkdir -p packaging/tools
wget -O packaging/tools/appimagetool.AppImage \
  https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage
chmod +x packaging/tools/appimagetool.AppImage
```

#### ❌ bundled gum 找不到

**原因**：首次執行時 gum 工具還未下載

**解決**：`package-appimage.sh` 會自動執行 `setup-deps.sh` 完成下載，無需手動干預。
或手動執行：
```bash
bash packaging/appimage/scripts/fetch-gum.sh
```

#### ❌ TUI 依賴未安裝

**原因**：新機器上 clone 後，TUI 的 node_modules 未安裝

**解決**：`package-appimage.sh` 會自動執行 `setup-deps.sh` 完成安裝，無需手動干預。
或手動執行：
```bash
cd tui && bun install && cd ..
```

## Release Modes

### Tag-driven (Primary)

- Trigger: push version tag（`v*`）
- Workflow: `.github/workflows/tag-driven-appimage-release.yml`
- Output assets:
  - `tty-clock-timer-<version>-linux-x86_64.AppImage`
  - `tty-clock-timer-<version>-linux-x86_64.AppImage.sha256`
  - `release-metadata-<version>.json`

### Manual (Fallback)

當 CI/環境異常導致 tag-driven 流程不可用時，維護者可使用下列固定介面手動完成同版本交付。

### 1) Build Core Artifact

```bash
./packaging/appimage/scripts/build-core.sh
```

- Fixed input: `core/` source tree
- Fixed output: `packaging/out/appimage/stage/usr/bin/tic`
- 補充：`package-appimage.sh` 會自動執行此步驟；此命令主要用於獨立檢查 core 產物。

### 2) Package AppImage Artifact

```bash
APPIMAGE_VERSION=<version> ./packaging/appimage/scripts/package-appimage.sh
```

- Fixed input:
  - `core/` source tree（由腳本內部強制 clean rebuild）
  - `tui/` runtime tree
  - `packaging/appimage/assets/*`
- Fixed output: `packaging/out/appimage/tty-clock-timer-<version>-linux-x86_64.AppImage`

### 3) Verify Artifact Checklist

```bash
APPIMAGE_VERSION=<version> ./packaging/appimage/scripts/verify-artifact.sh
```

- 檢查項目對齊 `checklist.md`：可執行、命名、必要資產存在。

### 4) MVP Runtime Smoke (Optional)

```bash
TTY_CLOCK_TUI_CWD="$(pwd)/packaging/appimage/scripts" \
TTY_CLOCK_TUI_ENTRY="timer-smoke.ts" \
./packaging/out/appimage/tty-clock-timer-<version>-linux-x86_64.AppImage --seconds 5

TTY_CLOCK_TUI_CWD="$(pwd)/packaging/appimage/scripts" \
TTY_CLOCK_TUI_ENTRY="mvp-smoke.ts" \
./packaging/out/appimage/tty-clock-timer-<version>-linux-x86_64.AppImage --seconds 20
```

## References

- Artifact contract: `packaging/appimage/artifact-contract.md`
- Release playbook: `packaging/appimage/release.md`
- MVP verification record: `packaging/appimage/verification.md`
