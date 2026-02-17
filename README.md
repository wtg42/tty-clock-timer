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

## AppImage 發佈與分發

`tty-clock-timer` 支援 Linux x86_64 AppImage 發行版本，提供獨立的、可攜帶的執行檔供最終使用者下載執行。

### 運行環境契約（Runtime Artifact Contract）

AppImage 與開發模式共用統一的 **Core-TUI artifact contract**，定義：

- **Core binary**: `usr/bin/tty_clock_timer`（AppImage 內唯一入口）
- **TUI runtime root**: `usr/lib/tty-clock-timer/tui`（由 core 以此作為工作目錄啟動）
- **TUI entry file**: `index.js`（可透過環境變數 `TTY_CLOCK_TUI_ENTRY` 覆蓋）
- **AppRun wrapper**: 設置環境變數後轉呼叫 core，不直接啟動 UI

詳細契約規範見 [packaging/appimage/artifact-contract.md](./packaging/appimage/artifact-contract.md)。

### Unix Socket IPC 與動態 Socket Path

Core 與 TUI 透過 Unix Domain Socket 進行雙向通訊。為支援多實例運行（避免衝突），**Core 每次執行時動態產生唯一的 socket path**（格式：`/tmp/tty-clock-timer-{random_hex}.sock`），並將其注入 TUI 子進程的命令行參數。

詳細機制見 [openspec/specs/unix-socket-ipc-bridge/spec.md](./openspec/specs/unix-socket-ipc-bridge/spec.md)。

### AppImage 構建與驗證

AppImage 打包流程包含固定的輸入與輸出介面：

1. **構建 Core 二進檔**：`./packaging/appimage/scripts/build-core.sh`
2. **打包 AppImage**：`APPIMAGE_VERSION=<version> ./packaging/appimage/scripts/package-appimage.sh`
3. **驗證 AppImage**：`APPIMAGE_VERSION=<version> ./packaging/appimage/scripts/verify-artifact.sh`
4. **MVP 煙霧測試**（可選）：使用 `mvp-smoke.ts` 或 `timer-smoke.ts` 驗證功能

詳細步驟與 release playbook 見 [packaging/appimage/](./packaging/appimage/) 目錄。
