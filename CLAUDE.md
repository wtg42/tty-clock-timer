# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**tty-clock-timer** is a terminal-based countdown timer application using a modern HTTP/SSE architecture. It consists of three components:
- **Server** (Bun): HTTP/REST API server with Server-Sent Events (SSE) for broadcasting timer updates
- **Core** (Zig): High-precision countdown timer engine running as a child process of the Server
- **TUI** (TypeScript/Solid): Terminal UI client that connects to the Server via HTTP/EventSource

The architecture separates concerns: the Server manages timer state and coordinates communication, Core handles high-precision timing, and TUI is a thin client displaying updates and handling keyboard input.

## Build & Run Commands

### Quick Start

```bash
# Terminal 1: Build Core and start Server
cd core && zig build && cd ..
PORT=8080 bun run server

# Terminal 2: Start TUI client (connects to Server on port 8080)
bun run tui
```

### Core (Zig)

All commands execute from `core/` directory:

```bash
# Build executable
zig build

# Run all tests (both library and executable)
zig build test

# Run single test file with filter
zig test core/src/lib/config.zig --test-filter "parseArgsFromSlice"

# Format code
zig fmt core/src/*.zig core/src/lib/*.zig
```

Note: Core is spawned by the Server, not run directly as a CLI tool.

### Server (Bun)

Execute from project root:

```bash
# Start HTTP server (spawns Core process, listens on port 8080)
bun run server

# Custom port
PORT=3000 bun run server

# Development mode (with watch)
bun run server:dev
```

### TUI Client (Bun/TypeScript)

Execute from project root:

```bash
# Start TUI client (connects to Server at http://localhost:8080)
bun run tui

# Custom server URL
SERVER_URL=http://localhost:3000 bun run tui
```

## Architecture & Module Structure

### Server (Bun/TypeScript)

- **`server/index.ts`**: HTTP server entry point. Initializes Bun.serve on configurable PORT (default 8080), spawns Core process, sets up graceful shutdown (SIGINT/SIGTERM), manages Core process lifecycle.

- **`server/routes.ts`**: REST API route handlers. Implements endpoints: `GET /status`, `GET /events` (SSE), `POST /start`, `POST /pause`, `POST /resume`, `POST /reset`, `POST /stop`. Validates requests and forwards commands to Core via `sendCommandToCore()`.

- **`server/timer-manager.ts`**: Core process lifecycle management. Spawns Core via `Bun.spawn()`, reads Core stdout (JSON messages), parses IPC messages (update_timer, timer_finished, exit), broadcasts updates via SSE.

- **`server/sse.ts`**: Server-Sent Events handler. Manages SSE client connections, broadcasts timer updates to all connected clients, handles client disconnection cleanup, sends keep-alive comments every 30 seconds.

- **`server/state.ts`**: Global timer state (single shared instance). Exports `timerState` object (status, remaining_seconds, total_duration, elapsed_seconds) and update functions. All clients observe the same timer.

### Core (Zig)

- **`core/src/main.zig`**: Timer process entry point. Runs in headless mode, reads JSON commands from stdin (`{"cmd": "start", "duration": N}`), updates timer, sends JSON messages to stdout (update_timer, timer_finished). Uses `std.process.Init` for I/O context.

- **`core/src/lib/config.zig`**: CLI argument parsing (`--minutes`, `--seconds`, `--help`). Returns `ParseError` union type on failure.

- **`core/src/lib/timer.zig`**: Core countdown timer with state machine (idle → running → paused → finished). Uses `std.time.Timer` for high-precision timing.

- **`core/src/lib/ipc.zig`**: JSON-based IPC protocol. Defines `Message` union (update_timer, timer_finished, exit, keyboard_input). All messages include explicit "type" field.

### TUI Client (TypeScript/Solid/OpenTUI)

- **`tui-client/src/index.tsx`**: HTTP client entry point. Connects to Server via `EventSource` to `/events` endpoint, receives SSE messages, updates Solid.js signals. Handles keyboard input (TTY raw mode), sends HTTP POST requests to control timer (`/start`, `/pause`, `/resume`, `/reset`, `/stop`). Renders via OpenTUI components.

## Key Design Patterns

### HTTP/SSE Communication

Timer updates flow:
1. Server spawns Core process via `Bun.spawn()`
2. Core reads commands from stdin: `{"cmd": "start", "duration": 300}`
3. Core sends updates to stdout: `{"type": "update_timer", ...}`
4. Server parses Core messages and broadcasts via SSE to all clients
5. TUI clients receive updates via EventSource, update UI reactively

SSE message format (sent by Server to clients):
```json
{"type": "update_timer", "remaining_seconds": 120, "total_duration": 300, "status": "running"}
```

Core command format (sent by Server to Core stdin):
```json
{"cmd": "start", "duration": 300}
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

- **Server spawns Core**: Server is the main process, spawns Core as child with stdin/stdout pipes.
- **TUI is independent client**: TUI connects to Server via HTTP, not a child process.
- **Graceful shutdown**: Server handles SIGINT/SIGTERM, sends exit command to Core, closes SSE connections.
- **Multi-client support**: Multiple TUI instances can connect to the same Server (read-only via SSE, commands via REST API).
- **Command JSON format**: Newline-delimited JSON on Core stdin/stdout.
- **SSE format**: Newline-delimited JSON on HTTP response body.

### Debugging

- **Server errors**: Check console output from `bun run server` (port conflicts, Core path issues).
- **Core crashes**: Server detects via `coreProcess.exited`, broadcasts error event to all SSE clients.
- **TUI connection errors**: Check if Server is running on expected port (`lsof -i :8080`).
- **Memory leaks** (Debug): `main.zig` deinit panics if leaks detected.
- **Test API**: `curl -s http://localhost:8080/status | jq .`

## OpenSpec Workflow

This project uses OpenSpec for change management:
- Use `/opsx:new` to create structured changes with artifacts (requirements, design, tasks, verification).
- Use `/opsx:apply` to implement tasks.
- Use `/opsx:archive` after verification.
- Language: Traditional Chinese (繁體中文) with technical terms in English.
