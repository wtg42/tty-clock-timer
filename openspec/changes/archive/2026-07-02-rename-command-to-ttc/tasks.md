## 1. Core CLI

- [x] 1.1 將 Zig executable name 從 `tic` 改為 `ttc`。
- [x] 1.2 將 CLI help 文本與 stable output test 改為 `ttc`。
- [x] 1.3 執行 core build/test，確認產物為 `zig-out/bin/ttc`。

## 2. AppImage Packaging

- [x] 2.1 更新 build/package/verify scripts，讓 staged/AppDir core binary 使用 `usr/bin/ttc`。
- [x] 2.2 更新 AppRun 與 desktop entry，使 runtime/desktop 入口執行 `ttc`。
- [x] 2.3 更新 AppImage artifact contract、checklist 與 packaging 文件中的 core binary 路徑。

## 3. Documentation and OpenSpec

- [x] 3.1 更新 README 與 release/playbook 類文件中的使用範例與安裝命名為 `ttc`。
- [x] 3.2 更新 current OpenSpec specs 中仍引用 `tic` 或 `tty_clock_timer` 的公開命令範例。
- [x] 3.3 更新未歸檔 completed change artifacts 中仍引用 `tic` 的命名敘述，避免後續 archive/sync 回歸舊名稱。

## 4. Verification

- [x] 4.1 執行 `openspec validate rename-command-to-ttc --strict`。
- [x] 4.2 執行 affected shell script syntax checks。
- [x] 4.3 執行 final grep，確認非 archive 範圍不再殘留正向 public `tic`、`usr/bin/tic` 或 `Exec=tic` 入口。
