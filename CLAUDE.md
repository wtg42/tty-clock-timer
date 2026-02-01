# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**tty-clock-timer** is a terminal-based countdown timer application with a terminal UI (TUI). It combines:
- **Core** (Zig): CLI entry point, argument parsing, timer logic, IPC communication with the UI process
- **TUI** (TypeScript/Solid): Visual display using OpenTUI framework

The architecture uses IPC (inter-process communication) to send timer updates from the Zig core to the Node.js-based OpenTUI UI via JSON messages over stdout/stdin.

## Build & Run Commands

### Core (Zig)

All commands execute from `core/` directory:

```bash
# Build executable
zig build

# Run with arguments
zig build run -- --minutes 25
zig build run -- -s 90

# Run all tests (both library and executable)
zig build test

# Run single test file with filter
zig test core/src/lib/config.zig --test-filter "parseArgsFromSlice"

# Format code
zig fmt core/src/*.zig core/src/lib/*.zig
```

### TUI (OpenTUI)

Execute from `tui/` directory:

```bash
# Development mode (with watch)
bun run dev

# Install dependencies
bun install
```

## Architecture & Module Structure

### Core (Zig)

- **`core/src/main.zig`**: CLI entry point. Initializes I/O context, parses CLI arguments via `config` module, manages the main event loop (polling stdin, updating timer, sending IPC messages). Uses `std.process.Init` to receive pre-initialized I/O from Zig 0.16 runtime.

- **`core/src/root.zig`**: Library public API (re-exports for external consumers).

- **`core/src/lib/config.zig`**: CLI argument parsing (`--minutes`, `--seconds`, `--help`). Returns `ParseError` union type on failure.

- **`core/src/lib/timer.zig`**: Core countdown timer with state machine (idle → running → paused → finished). Uses `std.time.Timer` for high-precision timing. Provides `CountdownTimer` struct with methods: `init()`, `start()`, `update()`, `isFinished()`, `reset()`, `getFormattedTime()`.

- **`core/src/lib/allocator.zig`**: Unified memory context with leak detection (Debug mode only). Provides `AllocatorCtx.init()` and `deinit()` with leak checking.

- **`core/src/lib/ipc.zig`**: JSON-based IPC protocol. Defines `Message` union (update_timer, timer_finished, exit, keyboard_input). Provides functions: `updateTimer()`, `notifyTimerFinished()`, `sendExit()`, `handleKeyboardInput()`, `parseMessage()`. All messages include a JSON "type" field.

### TUI (OpenTUI)

- **`tui/src/index.tsx`**: Entry point for OpenTUI. Receives JSON messages from stdin (timer updates), parses and filters messages, updates Solid.js signals (`remainingSeconds`, `timerStatus`). Renders via OpenTUI's `<box>`, `<text>`, `<ascii_font>` JSX components.

## Key Design Patterns

### IPC Communication

Timer updates flow: `main.zig` → JSON serialization → stdout → `index.tsx` stdin → state update → render

Messages are JSON objects with explicit "type" field:
```json
{"type": "update_timer", "remaining_seconds": 120, "total_duration": 300, "status": "running"}
```

### Error Handling

- **Zig**: Custom error enums (e.g., `ParseError`). Use `try`/`catch` at boundaries (CLI, I/O). Propagate errors via `!ReturnType`.
- **Boundaries**: CLI argument errors printed to stderr, I/O errors trigger process exit with code 1.

### Memory Management (Zig)

- Use `allocator_ctx.AllocatorCtx` for unified memory context.
- Debug mode: `DebugAllocator` detects leaks via `deinit()` check.
- All allocations paired with immediate `defer` cleanup.
- `Arena` allocator for temporary data structures.

## Testing

- **Zig**: Inline tests in source files using `test "description" { }` blocks.
- **Naming**: `"module/function - scenario"` (e.g., `"config/parseArgs - valid minutes"`).
- **Run tests**: `zig build test` or `zig test <file> --test-filter "<pattern>"`.
- **Error paths**: Use `std.testing.expectError(expected_error, call)`.

## Code Style

### Zig

- **Indentation**: 4 spaces (enforced by `zig fmt`).
- **Line length**: 100-120 characters.
- **Imports**: `std` first, then external modules, then local modules.
- **Naming**:
  - `snake_case`: functions, variables, modules
  - `CamelCase`: types, structs
  - `SCREAMING_SNAKE_CASE`: constants
- **Public API**: Minimize visible scope; group `pub` functions at file start.

### TypeScript/TSX (TUI)

- **Indentation**: 2 spaces.
- **Imports**: Third-party (`@opentui/*`, `solid-js`) first, then local.
- **Types**: Strict mode enabled (`tsconfig.json`).
- **JSX**: Use OpenTUI's `<box>`, `<text>`, `<ascii_font>` components. Keep state logic modular.

## Important Notes

### Zig std Library

Per `AGENTS.md`:
- **First priority**: Use local `zig-std-index` Skill: `bash .opencode/skill/zig-std-index/scripts/search.sh <keyword>`
- **Verification**: Always verify std APIs exist before implementation; Zig master changes rapidly.

### Process Architecture

- **Core spawns TUI**: Main (`main.zig`) spawns child process (bun + OpenTUI) with stdin pipe.
- **Graceful shutdown**: On timer finish or user quit ('q'), send exit message and close pipes.
- **IPC format**: Newline-delimited JSON on stdout/stdin.

### Debugging

- **Core errors**: Check stderr messages (I/O, timer start, IPC failures).
- **TUI not found**: Check stdout for "Error: UI directory not found" and tried paths.
- **Memory leaks** (Debug): `main.zig` deinit panics if leaks detected.

## OpenSpec Workflow

This project uses OpenSpec for change management:
- Use `/opsx:new` to create structured changes with artifacts (requirements, design, tasks, verification).
- Use `/opsx:apply` to implement tasks.
- Use `/opsx:archive` after verification.
- Language: Traditional Chinese (繁體中文) with technical terms in English.
