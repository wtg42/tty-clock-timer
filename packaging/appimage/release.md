# Release Playbook (Linux x86_64)

## 0) Preferred Path: Tag-driven Automation

主要發版路徑為 Git tag 觸發：

1. 建立並推送版本 tag（建議格式：`v<major>.<minor>.<patch>`）
2. GitHub Actions workflow `.github/workflows/tag-driven-appimage-release.yml` 自動執行 build/package/verify/upload
3. Workflow 成功後，GitHub Release 會附帶：
   - `tty-clock-timer-<version>-linux-x86_64.AppImage`
   - `tty-clock-timer-<version>-linux-x86_64.AppImage.sha256`
   - `release-metadata-<version>.json`

若自動化流程失敗，請依下方 Manual Fallback 完成交付。

## 1) Preflight Checks

在發版前先確認：

1. `zig`、`bun`、`appimagetool` 可用
2. `core/` 測試可跑（至少 `zig build test`）
3. `tui/` 相依完整（`node_modules` 與 runtime entry 存在）
4. 目前 branch 的 OpenSpec tasks 與驗收紀錄已更新

## 2) Manual Fallback: Build and Package Steps

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

## 5) Failure Signals and Fallback

tag-driven workflow 會在以下階段回報可判讀失敗訊號：

- `stage=build`
- `stage=package`
- `stage=verify`
- `stage=upload`

若任一階段失敗，維護者 MUST 回退至本文件第 2 節的 manual fallback 流程，並使用同一版本字串完成交付。
