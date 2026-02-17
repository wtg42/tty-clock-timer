# Packaging

此目錄包含 `tty-clock-timer` 的打包與發行相關檔案。目前支援 **AppImage** (Linux x86_64) 格式。

## 目錄結構

```text
packaging/
├── README.md            ← 本文件
├── appimage/            ← AppImage 打包骨架、腳本、資產
│   ├── README.md        ← AppImage 詳細文件
│   ├── artifact-contract.md
│   ├── checklist.md
│   ├── release.md
│   ├── verification.md
│   ├── assets/          ← .desktop、icon
│   └── scripts/         ← build / package / verify 腳本
├── tools/               ← 外部工具（如 appimagetool）
└── out/                 ← 建置產出（git-ignored）
    └── appimage/        ← AppImage 與中間產物
```

## 環境需求

| 工具 | 版本 | 說明 |
|------|------|------|
| `zig` | 0.16+ | 編譯 core binary |
| `bun` | 1.x | TUI runtime（host 需要安裝） |
| `appimagetool` | — | 打包 AppDir 為 `.AppImage`；放在 `packaging/tools/appimagetool.AppImage` 或設定 `APPIMAGETOOL_BIN` 環境變數 |

`appimagetool` 可從 [GitHub Releases](https://github.com/AppImage/appimagetool/releases) 下載。

## 快速開始

```bash
# 1. Build core binary
./packaging/appimage/scripts/build-core.sh

# 2. Package AppImage
APPIMAGE_VERSION=0.1.0 ./packaging/appimage/scripts/package-appimage.sh

# 3. Verify artifact
APPIMAGE_VERSION=0.1.0 ./packaging/appimage/scripts/verify-artifact.sh
```

產出路徑：`packaging/out/appimage/tty-clock-timer-<version>-linux-x86_64.AppImage`

## FAQ

### appimagetool 找不到怎麼辦？

腳本依序嘗試：
1. `APPIMAGETOOL_BIN` 環境變數指定的路徑
2. `packaging/tools/appimagetool.AppImage`
3. 系統 `PATH` 中的 `appimagetool`

建議將下載的 binary 放到 `packaging/tools/appimagetool.AppImage` 並設為可執行。

### AppImage 為什麼還需要 host 的 bun？

目前 TUI runtime 以原始碼形式打包（`tui/`），尚未內嵌 bun binary。AppImage 的 `AppRun` 會呼叫 host 的 `bun` 來執行 TUI。這是已知限制，未來可能改為 bundled runtime。

### `APPIMAGE_VERSION` 怎麼用？

此環境變數控制產出的檔名與版本標記。未設定時預設為 `dev`：

```bash
# 產出：tty-clock-timer-dev-linux-x86_64.AppImage
./packaging/appimage/scripts/package-appimage.sh

# 產出：tty-clock-timer-1.0.0-linux-x86_64.AppImage
APPIMAGE_VERSION=1.0.0 ./packaging/appimage/scripts/package-appimage.sh
```

### `out/` 目錄可以清掉嗎？

可以。`packaging/out/` 是建置產物目錄，可安全刪除並重新建置。

## 詳細文件

- [AppImage 打包說明](appimage/README.md)
- [Release Playbook](appimage/release.md)
- [Artifact Contract](appimage/artifact-contract.md)
- [打包檢查清單](appimage/checklist.md)
- [驗證紀錄](appimage/verification.md)
