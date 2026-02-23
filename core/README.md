# tty-clock-timer Core

`core/` is the Zig CLI runtime. It parses arguments, manages countdown timer state, launches the UI subprocess (when available), and exchanges commands/events with the TUI over Unix Domain Sockets.

## Current Features

- CLI supports `--minutes` / `--seconds` / `--help`.
- Launching with no args shows full help (same behavior as `--help`).
- Runtime allocator and I/O currently come from `main(init: std.process.Init)` via `init.gpa` and `init.io`.
- When UI startup is available, each run uses a unique socket: `/tmp/tty-clock-timer-*.sock`.
- UI runtime path resolution follows the contract: `TTY_CLOCK_TUI_CWD` -> `APPDIR` -> local fallback.
- If no UI connects, CLI fallback still supports quitting with stdin `q`.
- Timer events emitted: `update_timer`, `timer_finished`, `exit`.

## Directory Guide

- `src/main.zig`: CLI entry point. Integrates argument parsing, timer loop, UI process lifecycle, IPC, and I/O.
- `src/lib/config.zig`: CLI argument parsing and parse error semantics.
- `src/lib/timer.zig`: countdown timer logic and state machine.
- `src/lib/ipc.zig`: command/event messages, serialization, parsing, and helpers.

## Common Commands

```bash
zig build
zig build run -- --seconds 90
zig build test
```
