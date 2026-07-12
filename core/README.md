# tty-clock-timer Core

`core/` is the Zig CLI runtime. It parses arguments, manages countdown timer state, launches the UI subprocess (when available), and exchanges commands/events with the TUI over Unix Domain Sockets.

## Current Features

- CLI commands:
  - timer start: `--minutes <num>` / `--seconds <num>`
  - history select: `list`
  - history delete: `list --delete`
  - sound setup: `--setup-sound`
  - help: `--help` / `-h`
- Launching with no args shows full help (same behavior as `--help`).
- Runtime allocator and I/O come from `main(init: std.process.Init)` via `init.gpa` and `init.io`.
- Timer duration history is persisted to XDG state path (`$XDG_STATE_HOME` fallback to `$HOME/.local/state`), with dedup + recency ordering + max 10 entries.
- `list` uses the bundled prompt helper (`tui/dist/prompts/helper.js`) to select history durations.
- `list --delete` uses the bundled prompt helper for multi-select delete and prints remaining entries (or `no history`).
- `--setup-sound` supports player detection (`afplay`/`paplay`/`pw-play`/`aplay`/`mpg123`/`ffplay`), writes config to XDG config path, and exits without starting timer/TUI.
- Prompt flows are exchanged with the helper over JSON stdout payloads.
- When UI startup is available, each run uses a unique socket. Core prefers a usable, length-safe `TMPDIR` path and falls back to `/tmp/tty-clock-timer-*.sock` when needed.
- UI runtime path resolution follows the contract: `TTY_CLOCK_TUI_CWD` -> `APPDIR` -> local fallback.
- If no UI connects, CLI fallback still supports quitting with stdin `q`.
- Core emits events: `init`, `update_timer`, `timer_finished`, `exit`.

## Directory Guide

- `src/main.zig`: CLI entry point. Integrates argument parsing, list/setup-sound flows, timer loop, UI process lifecycle, IPC, and I/O.
- `src/lib/config.zig`: CLI argument parsing and parse error semantics.
- `src/lib/history.zig`: history storage/load/save/selection helpers.
- `src/lib/timer.zig`: countdown timer logic and state machine.
- `src/lib/ipc.zig`: command/event messages, serialization, parsing, and helpers.

## Common Commands

```bash
zig build
zig build run -- --seconds 90
zig build run -- list
zig build run -- list --delete
zig build run -- --setup-sound
zig build test
```
