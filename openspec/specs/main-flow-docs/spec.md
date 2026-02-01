# main-flow-docs Specification

## Purpose
TBD - created by archiving change update-main-todo-comment. Update Purpose after archive.
## Requirements
### Requirement: 主流程註解與實作一致

`core/src/main.zig` 的流程說明 MUST 反映實際已實作的行為，且不得暗示尚未完成的 TODO。

#### Scenario: 更新過期 TODO 描述

- **WHEN** 讀者查看 `main()` 的流程註解
- **THEN** 註解內容與實際主迴圈、timer 初始化與 IPC 行為一致
- **AND** 不包含「待實作」等過期描述

