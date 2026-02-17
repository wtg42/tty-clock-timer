# Manual Release Playbook (Linux x86_64)

## 1) Preflight Checks

在發版前先確認：

1. `zig`、`bun`、`appimagetool` 可用
2. `core/` 測試可跑（至少 `zig build test`）
3. `tui/` 相依完整（`node_modules` 與 runtime entry 存在）
4. 目前 branch 的 OpenSpec tasks 與驗收紀錄已更新

## 2) Build and Package Steps

```bash
./packaging/appimage/scripts/build-core.sh
APPIMAGE_VERSION=<version> ./packaging/appimage/scripts/package-appimage.sh
APPIMAGE_VERSION=<version> ./packaging/appimage/scripts/verify-artifact.sh

TTY_CLOCK_TUI_CWD="$(pwd)/packaging/appimage/scripts" \
TTY_CLOCK_TUI_ENTRY="timer-smoke.ts" \
./packaging/out/appimage/tty-clock-timer-<version>-linux-x86_64.AppImage --seconds 5

TTY_CLOCK_TUI_CWD="$(pwd)/packaging/appimage/scripts" \
TTY_CLOCK_TUI_ENTRY="mvp-smoke.ts" \
./packaging/out/appimage/tty-clock-timer-<version>-linux-x86_64.AppImage --seconds 20
```

> `APPIMAGE_VERSION` 未提供時預設為 `dev`。

## 3) Artifact Naming and Attached Information

### Naming Rule

`tty-clock-timer-<version>-linux-x86_64.AppImage`

### Required Attached Information

每次 release 應附上：

- `version`: 本次 release 版本字串
- `platform`: `linux-x86_64`
- `artifact_sha256`: AppImage SHA256
- `contract_check`: artifact contract 檢查摘要
- `mvp_check`: timer/key commands 驗收摘要

## 4) Suggested Release Notes Template

```text
Version: <version>
Platform: linux-x86_64
Artifact: tty-clock-timer-<version>-linux-x86_64.AppImage
SHA256: <sha256>

Contract checks:
- core binary: pass/fail
- tui runtime entry: pass/fail
- launch ownership by core: pass/fail

MVP checks:
- timer flow: pass/fail
- key commands: pass/fail

Known limitations:
- ...
```

## 5) Automation Handoff Notes (No CI/CD in this change)

後續若接自動化，建議分三個 job：

1. `build-core-linux-x86_64`
   - 執行 `build-core.sh`
   - 上傳 stage binary artifact
2. `package-appimage`
   - 下載 stage artifact
   - 執行 `package-appimage.sh`
   - 產出 AppImage
3. `verify-and-publish`
   - 執行 `verify-artifact.sh`
   - 計算 SHA256
   - 發佈到 release channel

自動化前提：仍必須維持「core 啟動 UI」契約，不新增平行啟動路徑。
