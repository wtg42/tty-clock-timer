# tty-clock-timer TUI

`tui/` is the OpenTUI (Solid) frontend. It renders countdown state, handles keyboard input, and communicates with the Zig core over Unix sockets.

## Development Commands

```bash
bun install
bun run dev
bun test
```

- `bun run dev`: runs `src/index.tsx` in watch mode.
- `bun test`: runs unit tests under `src/**/*.test.ts`.
- `tui/` currently has no standalone lint/type-check script (`tsconfig.json` is set to `noEmit`).

## Dependency Management Policy

- `tui/` is Bun-only for package management.
- Use `bun install` to add or update dependencies.
- `bun.lock` is the only lockfile allowed in `tui/`.
- Do not run npm commands in `tui/` to avoid regenerating `package-lock.json`.

## End-to-End TUI Data Flow (`src/` Responsibilities)

```text
Keyboard (p/r/s/q)
        |
        v
+-------------------+        uses         +------------------+
| src/index.tsx     | ------------------> | src/ui_logic.ts  |
| App + lifecycle   |                     | key/skip/dedup   |
+---------+---------+                     +------------------+
          |
          | issue command
          v
+-----------------------+   normalize   +---------------------------+
| src/command_plane.ts  | ------------> | CommandResponse (contract)|
+---------+-------------+               +---------------------------+
          |
          | send command JSON over unix socket
          v
+---------------------------+     IPC      +----------------------+
| src/unix_socket_adapter.ts| <----------> | Zig Core (core/)     |
| transport + correlation   |              | timer + command exec |
+---------+-----------------+              +----------+-----------+
          ^                                           |
          | CoreEvent JSON lines                      | emits events:
          |                                           | init /
          |                                           | update_timer /
          |                                           | timer_finished / exit
          +-----------------------------+-------------+
                                        |
                                        v
                              +-------------------+
                              | src/protocol.ts   |
                              | runtime guards    |
                              +---------+---------+
                                        |
                                        v
                              +-------------------+
                              | src/store.ts      |
                              | event projection  |
                              +---------+---------+
                                        |
                                        v
                              +-------------------+
                              | src/index.tsx     |
                              | render UI state   |
                              +-------------------+
```

## Module Responsibilities (`src/`)

- `src/index.tsx`: TUI composition root. Wires adapter/store/command plane, manages keyboard + connection lifecycle, then renders.
- `src/ui_logic.ts`: pure decision layer (time formatting, key-to-command mapping, status checks, short-window dedup).
- `src/command_plane.ts`: in-process command boundary. Normalizes the `POST /commands/:command` entrypoint and `CommandResponse`.
- `src/unix_socket_adapter.ts`: transport layer. Handles Unix socket connection, line-delimited JSON framing, and command request/response correlation.
- `src/protocol.ts`: protocol contract boundary. Defines command/event types and runtime guards (`isCoreEvent`, `isCommandResultMessage`).
- `src/store.ts`: event projection layer. Projects `CoreEvent` into `TimerViewState` and drives UI updates through a subscribe API.
- `src/sound.ts`: sound playback helper (`Bun.spawn`) used after timer completion when sound config exists.

## Protocol Contract

- TUI and core exchange JSON messages.
- Inbound events: `init`, `update_timer`, `timer_finished`, `exit`.
- `init` carries initial runtime config (`sound: SoundConfig | null`).
- Outbound commands: `pause`, `resume`, `reset`, `quit`.
- `src/protocol.ts` is the only type + runtime validation entrypoint, preventing unvalidated payloads from directly mutating UI state.

## Current Behavior

- Supported keys: `p` (pause), `r` (resume), `s` (reset), `q` (quit).
- Command path: `index.tsx` -> `command_plane.ts` -> `unix_socket_adapter.ts` -> core.
- Event path: core -> `unix_socket_adapter.ts` -> `protocol.ts` guard -> `store.ts` -> `index.tsx` render.
- Startup includes socket retry loop (500ms interval) until connected or shutdown.
- UI applies command dedup (250ms window) and repeated error dedup (1000ms window).
- Socket path is generated uniquely by core on every run (to avoid multi-instance collisions), with optional override via `--socket-path <path>`.
- On `timer_finished`, TUI plays configured sound via `playSound(player, file)` when `init.sound` is available; playback failures are silent by design.

## Unit Test Scope (Current)

- Only function-level unit tests are included.
- Test files live alongside target functions and use `*.test.ts` naming (for example, `store.test.ts`).
- Test case names follow a `function/scenario` style for faster failure triage.
- Feature tests are **not currently included** (cross-module flows, full UI interaction, E2E).

### Test Coverage Map

- `ui_logic.ts`: `formatRemaining`, `commandFromKey`, `shouldSkipByStatus`, `shouldSkipByDedup`
- `protocol.ts`: `isCoreEvent`、`isCommandResultMessage`
- `store.ts`: event projection behavior of `createTimerStore`
