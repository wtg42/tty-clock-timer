# tty-clock-timer

`tty-clock-timer` 是一個以 Zig 為核心、OpenTUI 為介面的終端倒數計時器。專案目前採用「Core 管理狀態 + TUI 呈現與互動」的分層架構，兩者透過 Unix Domain Socket 溝通。

## 架構總覽

- `core/`（Zig）：CLI 參數解析、timer 狀態機、IPC server、UI 子程序啟動。
- `tui/`（TypeScript + OpenTUI/Solid）：畫面渲染、鍵盤操作、command plane、socket client。
- `openspec/`：需求、設計、任務與變更歷程。
- Core runtime 資源由 `main(init: std.process.Init)` 提供：allocator 使用 `init.gpa`、I/O 使用 `init.io`。

## 系統流程（ASCII）

```text
┌────────────────────────────────────────────────────────────────────┐
│                         User / Terminal                            │
│             tty_clock_timer --minutes 25 / --seconds 90            │
└────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│                         Zig Core (core/)                           │
│ 1) parse args                                                      │
│ 2) init countdown timer                                            │
│ 3) setup unique Unix socket server (/tmp/tty-clock-timer-*.sock)   │
│ 4) spawn TUI process (bun run <entry> -- --socket-path <unique>)    │
└────────────────────────────────────────────────────────────────────┘
                     │                               │
                     │ timer events                  │ commands
                     │ (update_timer,                │ (pause/resume/reset/quit)
                     │  timer_finished, exit)        │
                     ▼                               ▲
┌────────────────────────────────────────────────────────────────────┐
│                  Unix Domain Socket IPC Bridge                     │
└────────────────────────────────────────────────────────────────────┘
                     │                               ▲
                     │ event stream                  │ command stream
                     ▼                               │
┌────────────────────────────────────────────────────────────────────┐
│                    OpenTUI UI (tui/src/index.tsx)                  │
│ - receive events -> update store -> render                         │
│ - key input (p/r/s/q) -> command plane -> socket adapter -> core   │
└────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│                        Terminal Rendering                          │
│        countdown (MM:SS), status, finished animation/error         │
└────────────────────────────────────────────────────────────────────┘
```

## 主要互動邏輯

```text
[No args or --help]
  -> Core prints help and exits.

[With --minutes/--seconds]
  -> Core starts timer loop.
  -> Core resolves TUI runtime contract (TTY_CLOCK_TUI_CWD/TTY_CLOCK_TUI_ENTRY/APPDIR).
  -> If TUI connects: use socket command/event flow.
  -> If TUI not connected: fallback stdin path supports q to quit.
```

## 快速開始

### Core

```bash
cd core
zig build
zig build run -- --seconds 90
zig build test
```

### TUI（單獨開發）

```bash
cd tui
bun install
bun run dev
```
