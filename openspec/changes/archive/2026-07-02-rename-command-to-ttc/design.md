## Context

專案已將公開命令定義為 `tic`，但 Linux 系統常見 `ncurses` 工具也提供 `/usr/bin/tic`。使用者若將 AppImage 安裝目錄加入 `PATH`，會在本專案命令與系統命令之間產生命名衝突。

現況中 `tic` 同時出現在 Zig executable 名稱、CLI help、AppImage staging/AppDir/AppRun、desktop entry、文件、OpenSpec current specs，以及未歸檔 completed change artifact。若只改程式碼而不改規格或 pending artifacts，後續 archive/sync 可能重新引入舊命名。

## Goals / Non-Goals

**Goals:**

- 將公開 CLI 命令與 AppImage 內 core binary 統一改為 `ttc`。
- 確保 help、docs、packaging verify 與 OpenSpec 規格一致引用 `ttc`。
- 避免未歸檔 completed change artifacts 在後續流程中把 `tic` 帶回。

**Non-Goals:**

- 不更改產品名稱 `tty-clock-timer`。
- 不更改 AppImage release 檔名 pattern、設定檔目錄、socket path、icon 名稱或 desktop file 檔名。
- 不提供 `tic` 相容 alias，避免保留衝突來源。

## Decisions

- 決策：使用 `ttc` 作為唯一公開命令與 AppImage 內部 core binary 名稱。
  - 原因：`ttc` 未在目前系統 PATH 中出現，且比 `tty-clock-timer` 短。
  - 替代方案：保留 `tic` alias。否決，因為 alias 會延續 PATH 衝突風險。
- 決策：AppImage 檔名仍維持 `tty-clock-timer-<version>-linux-x86_64.AppImage`。
  - 原因：檔名代表產品與 release artifact，不是 shell command；改檔名會增加不必要的發版相容成本。
- 決策：同步更新未歸檔 completed OpenSpec artifacts 中的 `tic`。
  - 原因：這些 artifacts 仍可能被 archive/sync，若保留舊命名會污染 main specs。

## Risks / Trade-offs

- 舊使用者已習慣 `tic` → release notes 與 README 明確標示改用 `ttc`。
- 本次為 breaking CLI rename → 不提供 alias 以換取避免系統命令衝突的明確行為。
- OpenSpec current specs 既有少數 `tty_clock_timer` 舊命名 → 本次一併將受影響命令範例收斂到 `ttc`。
