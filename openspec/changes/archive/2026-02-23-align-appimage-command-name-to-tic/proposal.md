## Why

目前 AppImage 打包流程已將 core binary 改名為 `tic`，但 verify 與 desktop entry 仍有 `tty_clock_timer` 舊命名殘留，導致 CI verify 階段誤判失敗，且發行產物行為與命名規格不一致。

## What Changes

- 更新 AppImage verify 規則，改為檢查 `AppDir/usr/bin/tic` 的存在與 executable 權限。
- 對齊 AppImage desktop entry 的 `Exec` 欄位為 `tic`，避免 runtime 透過舊命令名稱啟動。
- 同步 AppImage 打包相關文件與驗收敘述中的舊命令路徑，避免後續維護再次回歸舊命名。

## Capabilities

### New Capabilities
- 無

### Modified Capabilities
- `appimage-packaging-workflow`: 將 AppImage 驗收與流程敘述中的 core binary 路徑由 `tty_clock_timer` 對齊為 `tic`，確保 verify 與實際產物一致。
- `cli-command-naming`: 強化打包構件層面的命令一致性，要求 AppImage desktop entry 與 runtime 構件全面使用 `tic`。

## Impact

- Affected code: `packaging/appimage/scripts/verify-artifact.sh`、`packaging/appimage/assets/tty-clock-timer.desktop`。
- Affected docs/specs: `packaging/appimage/README.md`、`openspec/specs/appimage-packaging-workflow/spec.md`（以及對應 change delta specs）。
- CI impact: 修復 tag-driven AppImage release 的 verify 階段誤報失敗。
