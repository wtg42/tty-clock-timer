## Core Coverage Checklist

### config (core/src/lib/config.zig)
- High-risk paths:
  - Missing arguments
  - Missing minutes/seconds value
  - Unknown argument
  - Invalid numeric value
  - Overflow when minutes * 60
- Boundary inputs:
  - Non-numeric strings
  - Max u32 minutes overflow boundary

### timer (core/src/lib/timer.zig)
- High-risk paths:
  - State transitions (idle/running/paused/finished)
  - Update when not running
  - Finish detection at zero
- Boundary inputs:
  - Remaining time at 0 or 1
  - Pause/unpause no-op when not paused

### ipc (core/src/lib/ipc.zig)
- High-risk paths:
  - JSON parse with missing fields
  - Invalid field types
  - Unknown message type
  - Keyboard input filtering
- Boundary inputs:
  - Negative or overflow integer fields
  - Non-string key/status fields

### main (core/src/main.zig)
- High-risk paths:
  - CLI parse error mapping
  - Help output flow
  - IPC error handling on send/update
- Boundary inputs:
  - Error types mapping coverage
