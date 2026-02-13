# tty-clock-timer Core

`core/` 是 Zig CLI 核心，負責解析參數、管理倒數計時狀態、啟動 UI 子程序（可用時），並透過 Unix Domain Socket 與 TUI 交換 command/event。

## 目前功能

- CLI 支援 `--minutes` / `--seconds` / `--help`。
- 無參數啟動時會顯示完整 help（與 `--help` 一致）。
- 若可啟動 UI，會嘗試連接並使用預設 socket：`/tmp/tty-clock-timer.sock`。
- 若沒有 UI 連線，仍可在 CLI 路徑透過 stdin `q` 結束。
- Timer 事件會輸出 `update_timer`、`timer_finished`、`exit`。

## 目錄說明

- `src/main.zig`：CLI entry point，整合參數解析、timer loop、UI process、IPC 與 I/O。
- `src/lib/config.zig`：CLI 參數解析與錯誤語意。
- `src/lib/timer.zig`：倒數計時與狀態機。
- `src/lib/ipc.zig`：command/event message、序列化、解析與 helper。
- `src/lib/allocator.zig`：allocator context 與生命週期管理。

## 常用指令

```bash
zig build
zig build run -- --seconds 90
zig build test
```
