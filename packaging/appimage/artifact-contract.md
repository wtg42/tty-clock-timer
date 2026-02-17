# Core-TUI Artifact Contract

此文件定義 AppImage / 開發模式共用的 core-to-TUI runtime contract。

## Artifact Inventory

| Artifact | Required | Contract Path | Notes |
| --- | --- | --- | --- |
| Core binary | Yes | `usr/bin/tty_clock_timer` | AppImage 內唯一主入口 |
| TUI runtime root | Yes | `usr/lib/tty-clock-timer/tui` | 由 core 作為 `cwd` 啟動 |
| TUI entry file | Yes | `src/index.tsx` | 可用 `TTY_CLOCK_TUI_ENTRY` 覆蓋 |
| AppRun wrapper | Yes | `AppRun` | 只設置 contract env，最後執行 core |

## Runtime Path Resolution Order

core 啟動 TUI 時，`cwd` MUST 依序解析：

1. `TTY_CLOCK_TUI_CWD`（明確 override）
2. `APPDIR/usr/lib/tty-clock-timer/tui`（AppImage runtime）
3. `tui`
4. `../tui`
5. `../../tui`

entry 解析規則：

- `TTY_CLOCK_TUI_ENTRY`（若存在）
- 否則使用 `src/index.tsx`

## Launch Interface

core MUST 使用單一路徑啟動 UI，不允許平行啟動實作。

```text
bun run <entry> -- --socket-path <unique-socket-path>
```

- `<entry>` 由 contract entry 解析
- `<unique-socket-path>` 由 core 每次執行動態產生
- TUI process lifecycle 由 core 建立/管理/回收

## Error Contract

### Missing Artifact

當 contract `cwd` 無法解析時，core MUST：

- 輸出 `Missing TUI runtime artifact` 類型訊息
- 列出已嘗試路徑清單
- 提示可透過 `TTY_CLOCK_TUI_CWD` 修正

### Invalid Entry

當 contract `entry` 在已解析 `cwd` 下不存在或不可讀時，core MUST：

- 輸出 `Invalid TUI runtime entry` 類型訊息
- 顯示 runtime `cwd` 與 entry 值
- 提示可透過 `TTY_CLOCK_TUI_ENTRY` 修正

## AppImage Boundary

- AppRun 只做環境變數設定與轉呼叫 core
- UI 啟動責任保持在 core
- 不新增由 AppRun 或其他外部腳本直接啟動 UI 的平行路徑
