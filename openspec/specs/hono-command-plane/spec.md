# hono-command-plane Specification

## Purpose
TBD - created by syncing change hono-rpc-unix-socket-ipc. Update Purpose after sync.

## Requirements

### Requirement: OpenTUI 使用 in-process RPC 發送命令
系統 MUST 提供 Node 進程內的 Hono command endpoint，讓 OpenTUI 可透過 in-process `fetch/RPC` 發送控制命令，而不直接耦合底層 IPC transport。

#### Scenario: UI 發送 pause 命令
- **WHEN** 使用者在 OpenTUI 觸發 pause 動作
- **THEN** UI MUST 透過 Hono command endpoint 發送 `pause` 命令並收到可判讀的成功回應

### Requirement: 命令回應語意一致
系統 MUST 對 command plane 回應統一結構，至少區分成功與失敗，且失敗時 MUST 回傳可供 UI 顯示或判斷的錯誤資訊。

#### Scenario: Core 拒絕不合法命令
- **WHEN** UI 發送目前狀態不允許的命令（例如重複 pause）
- **THEN** Hono command endpoint MUST 回傳一致格式的失敗結果與錯誤代碼/訊息
