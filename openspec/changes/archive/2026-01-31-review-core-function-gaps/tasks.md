## 1. Coverage Scope Review

- [x] 1.1 Audit core modules (config/timer/ipc/main) for missing tests and record high-risk paths
- [x] 1.2 Document boundary inputs and error scenarios per module in a coverage checklist

## 2. Test Coverage Expansion

- [x] 2.1 Add unit tests for config error and boundary cases (invalid numbers, overflow, missing values)
- [x] 2.2 Add unit tests for timer state transitions and edge timing conditions
- [x] 2.3 Add unit tests for ipc parsing errors, invalid payloads, and keyboard filtering
- [x] 2.4 Add unit tests for main error message mapping and CLI error flows

## 3. Verification

- [x] 3.1 Run targeted zig test per module and capture failures for fixes
- [x] 3.2 Run zig fmt on core sources after changes
