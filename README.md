# tty-clock-timer

A terminal-based countdown timer with a modern HTTP/SSE architecture supporting multiple concurrent clients.

## Features

- **High-precision countdown timer** (Zig backend)
- **Real-time updates** via Server-Sent Events (SSE)
- **Multi-client support** (multiple TUI instances can connect to the same timer)
- **REST API** for timer control
- **Keyboard controls** in TUI mode (space to pause/resume, 'q' to quit)
- **Beautiful terminal UI** with OpenTUI framework

## Quick Start

### 1. Prerequisites

- [Bun](https://bun.sh/) (for Node.js runtime)
- [Zig](https://ziglang.org/) (for building Core)

### 2. Build Core

```bash
cd core
zig build
cd ..
```

This creates `core/zig-out/bin/tty_clock_timer`.

### 3. Start Server

In a terminal, start the HTTP server (which spawns Core internally):

```bash
bun run server
```

The server will output:
```
Starting timer server on port 8080...
Server running on :8080
Spawning Core process: .../tty_clock_timer
Core process spawned with PID: ####
Info: Headless mode - waiting for start command
```

### 4. Start TUI Client

In another terminal, start the TUI client:

```bash
bun run tui
```

The TUI will connect to the server and display the timer interface.

### 5. Use the Timer

- **Start**: Send a POST request or use the API (see below)
- **Pause/Resume**: Press spacebar
- **Quit**: Press 'q'

## API Documentation

### REST Endpoints

Base URL: `http://localhost:8080`

#### Get Timer Status

```bash
GET /status
```

Response:
```json
{
  "status": "idle|running|paused|finished",
  "remaining_seconds": 120,
  "total_duration": 300,
  "elapsed_seconds": 180
}
```

#### Start Timer

```bash
POST /start
Content-Type: application/json

{"duration_seconds": 300}
```

#### Pause Timer

```bash
POST /pause
```

Returns error if timer is not running.

#### Resume Timer

```bash
POST /resume
```

Returns error if timer is not paused.

#### Reset Timer

```bash
POST /reset
```

#### Stop Server

```bash
POST /stop
```

Gracefully shuts down the server and Core process.

### Server-Sent Events

```bash
curl -N http://localhost:8080/events
```

Receives real-time timer updates as SSE messages:

```
data: {"type":"update_timer","remaining_seconds":120,"total_duration":300,"status":"running"}
data: {"type":"update_timer","remaining_seconds":119,"total_duration":300,"status":"running"}
...
data: {"type":"timer_finished"}
```

## Architecture

### Components

1. **Server** (Bun/TypeScript): HTTP/REST API with SSE broadcasting
   - Manages global timer state
   - Spawns and communicates with Core process
   - Broadcasts updates to all connected TUI clients

2. **Core** (Zig): High-precision countdown timer engine
   - Runs as child process of Server
   - Communicates via JSON on stdin/stdout
   - Handles pause, resume, reset operations

3. **TUI** (TypeScript/Solid): Terminal UI client
   - Connects to Server via HTTP/EventSource
   - Displays real-time timer updates
   - Sends control commands via REST API

### Flow

```
User (Terminal 1)        User (Terminal 2)
    ↓                          ↓
  TUI Client              TUI Client
    ↓                          ↓
  HTTP/SSE ────────────────────┐
                                ↓
                            ┌─Server─┐
                            │        │
                            │ State  │
                            │        │
                            └───┬────┘
                                │
                            JSON stdin/stdout
                                │
                              ┌─Core─┐
                              │      │
                              │Timer │
                              │ Zig  │
                              └──────┘
```

## Configuration

### Server Port

By default, the server listens on port `8080`. To use a different port:

```bash
PORT=3000 bun run server
```

### Server URL (from TUI)

By default, TUI connects to `http://localhost:8080`. To connect to a different server:

```bash
SERVER_URL=http://localhost:3000 bun run tui
```

## Development

### Build Commands

See [CLAUDE.md](./CLAUDE.md) for detailed development instructions.

### Testing API

```bash
# Start timer for 60 seconds
curl -X POST http://localhost:8080/start \
  -H "Content-Type: application/json" \
  -d '{"duration_seconds": 60}'

# Check status
curl http://localhost:8080/status | jq

# Pause
curl -X POST http://localhost:8080/pause

# Resume
curl -X POST http://localhost:8080/resume

# Reset
curl -X POST http://localhost:8080/reset

# Watch SSE stream
curl -N http://localhost:8080/events
```

## Troubleshooting

### Port Already in Use

If you see `Error: Port 8080 is already in use`, either:
1. Wait a moment and try again
2. Use a different port: `PORT=3000 bun run server`
3. Kill the existing process: `lsof -i :8080 | grep -v PID | awk '{print $2}' | xargs kill`

### Core Binary Not Found

Make sure you've built Core:
```bash
cd core && zig build && cd ..
```

### TUI Can't Connect to Server

Check that the server is running on the expected port:
```bash
curl http://localhost:8080/status
```

If the server is on a different port, set `SERVER_URL`:
```bash
SERVER_URL=http://localhost:3000 bun run tui
```

## License

MIT
