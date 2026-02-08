# Timer Server

HTTP/REST API server for the tty-clock-timer application. The server manages global timer state, spawns the Core timer process, and broadcasts updates to connected clients via Server-Sent Events (SSE).

## Architecture

The Server is the central coordination point:

1. **Spawns Core process**: Runs the high-precision Zig timer engine as a child process
2. **Manages state**: Maintains a single global timer state shared across all clients
3. **HTTP API**: Provides REST endpoints for timer control
4. **SSE broadcasting**: Streams real-time updates to all connected clients
5. **Process monitoring**: Detects Core crashes and notifies clients

## Quick Start

```bash
# Start the server (default port 8080)
bun run server

# Or use a custom port
PORT=3000 bun run server
```

The server will:
- Start listening on the specified port
- Spawn the Core timer process
- Print startup info to console
- Wait for client connections via HTTP

## REST API

### Endpoints

#### GET /status

Get the current timer state.

```bash
curl http://localhost:8080/status
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

#### POST /start

Start a new timer with the specified duration.

```bash
curl -X POST http://localhost:8080/start \
  -H "Content-Type: application/json" \
  -d '{"duration_seconds": 300}'
```

Request body:
- `duration_seconds` (number, required): Duration in seconds

Response:
```json
{
  "status": "started",
  "duration": 300
}
```

Errors:
- `400`: Missing or invalid `duration_seconds`
- `409`: Timer already running

#### POST /pause

Pause a running timer.

```bash
curl -X POST http://localhost:8080/pause
```

Response:
```json
{"status": "paused"}
```

Errors:
- `400`: Timer not running

#### POST /resume

Resume a paused timer.

```bash
curl -X POST http://localhost:8080/resume
```

Response:
```json
{"status": "running"}
```

Errors:
- `400`: Timer not paused

#### POST /reset

Reset the timer to idle state.

```bash
curl -X POST http://localhost:8080/reset
```

Response:
```json
{"status": "idle"}
```

#### POST /stop

Gracefully shut down the server and Core process.

```bash
curl -X POST http://localhost:8080/stop
```

Response:
```json
{"status": "stopping"}
```

The server will gracefully shut down over the next few seconds.

#### GET /events (Server-Sent Events)

Connect to receive real-time timer updates.

```bash
curl -N http://localhost:8080/events
```

The endpoint streams newline-delimited JSON events:

```
data: {"type":"update_timer","remaining_seconds":120,"total_duration":300,"status":"running"}
data: {"type":"update_timer","remaining_seconds":119,"total_duration":300,"status":"running"}
data: {"type":"timer_finished"}
```

Event types:
- `update_timer`: Timer tick event (sent every ~1 second)
  - `remaining_seconds` (number): Seconds remaining
  - `total_duration` (number): Total duration in seconds
  - `status` (string): "running", "paused", "idle", or "finished"

- `timer_finished`: Timer completion notification

- `error`: Error notification (e.g., Core crash)
  - `message` (string): Error description

## Module Structure

### index.ts

Server entry point. Initializes HTTP server, spawns Core process, and sets up graceful shutdown.

### routes.ts

REST API route handlers. Dispatches requests to appropriate handlers based on HTTP method and pathname.

### timer-manager.ts

Core process lifecycle management:
- Spawns Core via `Bun.spawn()`
- Reads Core stdout (JSON messages)
- Parses IPC protocol (update_timer, timer_finished, exit)
- Sends commands to Core stdin
- Monitors Core for crashes

### sse.ts

Server-Sent Events handler:
- Creates new SSE connections
- Manages active client connections
- Broadcasts messages to all clients
- Handles client disconnections
- Sends keep-alive comments

### state.ts

Global timer state and update functions:
- `timerState`: Shared object containing (status, remaining_seconds, total_duration, elapsed_seconds)
- `sseClients`: Set of active SSE client connections
- `updateTimerState()`: Updates state from Core messages
- `resetTimerState()`: Resets state to idle

### types.ts

TypeScript type definitions for IPC messages, timer state, and SSE clients.

## Core Communication

The Server communicates with Core via JSON-formatted messages over stdin/stdout.

### Messages from Core (stdout)

Core sends these message types to Server:

#### update_timer
```json
{
  "type": "update_timer",
  "remaining_seconds": 120,
  "total_duration": 300,
  "status": "running"
}
```

Sent approximately every 1 second while timer is running or paused.

#### timer_finished
```json
{
  "type": "timer_finished",
  "total_duration": 300
}
```

Sent when the timer countdown reaches zero.

#### exit
```json
{
  "type": "exit"
}
```

Sent when Core is shutting down.

### Commands to Core (stdin)

Server sends these commands to Core:

#### start
```json
{"cmd": "start", "duration": 300}
```

Start a timer with the specified duration in seconds.

#### pause
```json
{"cmd": "pause"}
```

Pause the running timer.

#### resume
```json
{"cmd": "resume"}
```

Resume a paused timer.

#### reset
```json
{"cmd": "reset"}
```

Reset the timer to idle state.

#### exit
```json
{"cmd": "exit"}
```

Shut down the Core process.

## Error Handling

### Port Conflict

If the specified port is already in use:
```
Error: Port 8080 is already in use.
Please specify a different port using the PORT environment variable.
Example: PORT=3000 bun run server
```

### Core Binary Not Found

If Core binary cannot be located:
```
Failed to spawn Core process: Error: Core binary not found. Tried paths:
./core/zig-out/bin/tty_clock_timer
./zig-out/bin/tty_clock_timer
... (more paths)
```

Make sure Core is built:
```bash
cd core && zig build && cd ..
```

### Core Crash

If Core crashes, the Server will:
1. Detect the process exit
2. Log the error: `Core process crashed with exit code: N`
3. Broadcast an error event to all SSE clients:
```json
{"type": "error", "message": "Core process crashed with exit code 1"}
```

Clients can reconnect and retry.

## Configuration

### PORT

Listen on a custom port (default: 8080):
```bash
PORT=3000 bun run server
```

## Monitoring

### Server Logs

The Server prints operational logs to stdout/stderr:

```
Starting timer server on port 8080...
Server running on :8080
Spawning Core process: /path/to/tty_clock_timer
Core process spawned with PID: 12345
Info: Headless mode - waiting for start command
SSE client connected: client-1 (total: 1)
SSE client disconnected: client-1 (total: 0)
Shutting down server...
Terminating Core process...
Core process exited gracefully
Server shut down successfully
```

### Health Check

To verify the server is running:
```bash
curl http://localhost:8080/status
```

Should return a JSON status object.

### Monitor Active Connections

Monitor SSE client connections through logs:
```bash
bun run server | grep "SSE client"
```

## Development

### Watch Mode

Auto-reload on file changes:
```bash
bun run server:dev
```

### Testing

Test specific endpoints with curl:

```bash
# Start a 10-second timer
curl -X POST http://localhost:8080/start \
  -H "Content-Type: application/json" \
  -d '{"duration_seconds": 10}'

# Check status every second
watch -n 1 'curl -s http://localhost:8080/status | jq'

# Monitor SSE stream
curl -N http://localhost:8080/events | jq 'fromjson'
```

## Performance Considerations

- **Single shared timer**: All clients observe the same timer instance
- **SSE latency**: Network latency is typically 1-5ms on localhost
- **Update frequency**: Timer updates sent at ~1 second intervals by Core
- **Client limit**: Tested with 100+ concurrent clients
- **Memory**: Server maintains one global state object (~100 bytes) + one SSE connection per client

## Troubleshooting

### Server starts but Core doesn't spawn

Check logs for:
- `Failed to spawn Core process`: Core binary not found, build it with `cd core && zig build`
- Permissions issue: Verify `core/zig-out/bin/tty_clock_timer` is executable

### Timer updates not visible in SSE stream

1. Verify server is running: `curl http://localhost:8080/status`
2. Start a timer: `curl -X POST http://localhost:8080/start -H "Content-Type: application/json" -d '{"duration_seconds": 60}'`
3. Check SSE stream: `curl -N http://localhost:8080/events`

### "Error: Port 8080 is already in use"

Use a different port:
```bash
PORT=3000 bun run server
```

Or kill the existing process:
```bash
lsof -i :8080 | grep -v PID | awk '{print $2}' | xargs kill
```
