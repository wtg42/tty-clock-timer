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
    ├── build-core.sh
    ├── mvp-smoke.ts
    ├── package-appimage.sh
    ├── timer-smoke.ts
    └── verify-artifact.sh
```

## Fixed Build/Package Interface

`package-appimage.sh` 預設採用 repo-local clean rebuild：每次執行都會先清理以下路徑，再重建 core 與 TUI。

- `packaging/out/appimage/stage`
- `packaging/out/appimage/AppDir`
- `core/zig-out`
- `core/.zig-cache`
- `tui/dist`

此策略不會清除全域 cache（例如 Bun 全域快取），但會增加單次打包時間，以換取跨機器與跨分支的一致產物。

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
- Fixed output: `packaging/out/appimage/stage/usr/bin/tty_clock_timer`
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
