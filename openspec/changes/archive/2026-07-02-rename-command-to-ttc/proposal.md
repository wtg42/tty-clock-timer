## Why

目前主要命令 `tic` 會與 Linux 系統既有的 `/usr/bin/tic` 衝突，使用者將 AppImage 安裝目錄加入 `PATH` 後容易蓋掉系統工具或啟動錯誤程式。需要將本專案的公開 CLI 命令改為不衝突的 `ttc`。

## What Changes

- **BREAKING**: 主要命令由 `tic` 改為 `ttc`，不保留 `tic` 相容 alias。
- Zig core executable、CLI help、README、AppImage AppRun、desktop entry、package/verify 腳本全面改用 `ttc`。
- OpenSpec 現行規格與未歸檔 completed change artifacts 中的命名要求同步改為 `ttc`，避免後續 archive/sync 把 `tic` 帶回。
- 保留產品名稱、AppImage 檔名 pattern、設定檔目錄、socket path、icon 與 desktop file 檔名的 `tty-clock-timer` 命名。

## Capabilities

### New Capabilities

- 無

### Modified Capabilities

- `cli-command-naming`: 主要命令名稱由 `tic` 改為 `ttc`。
- `cli-help-default-behavior`: help 與錯誤情境範例改為 `ttc`。
- `appimage-packaging-workflow`: AppImage 內 core binary 驗收路徑改為 `usr/bin/ttc`。
- `core-tui-artifact-contract`: artifact contract 內 core binary path 改為 `usr/bin/ttc`。
- `sound-setup-cli`: `--setup-sound` 的使用命令改為 `ttc --setup-sound`。
- `history-duration-selection`: history list 與 delete 模式的使用命令改為 `ttc list` / `ttc list --delete`。
- `list-delete-mode`: delete 模式的使用命令改為 `ttc list --delete`。
- `tag-driven-appimage-release`: dry-run/release build 對 core executable 的命名期待改為 `ttc`。

## Impact

- Affected code: `core/build.zig`、`core/src/main.zig`、AppImage packaging scripts、desktop entry。
- Affected docs/specs: README、packaging docs/checklists、current OpenSpec specs、未歸檔 completed change artifacts。
- Release impact: 後續 AppImage 內部入口為 `usr/bin/ttc`；AppImage 檔名仍維持 `tty-clock-timer-<version>-linux-x86_64.AppImage`。
