# terminal-input-hygiene Specification

## Purpose
TBD - created by archiving change fix-ghostty-input-artifacts. Update Purpose after archive.
## Requirements
### Requirement: TUI 僅以鍵盤事件觸發控制命令
系統 MUST 僅在收到可辨識的使用者鍵盤事件時，才觸發 `pause`、`resume`、`reset`、`quit` 命令；系統 MUST NOT 以原始 stdin 位元組流直接逐字映射命令。

#### Scenario: 無使用者按鍵時不得自動送命令
- **WHEN** 倒數開始後使用者未按任何控制鍵（包含 Ghostty 非 tmux 環境）
- **THEN** TUI MUST NOT 自動發送任何 `pause`/`resume`/`reset`/`quit` 命令，且 UI 不得出現由命令誤觸發產生的 `invalid_state`

### Requirement: 重複鍵盤事件必須可抑制噪音
系統 MUST 對持續按壓造成的重複事件提供抑制機制，避免短時間內重複送出同一不合法命令而產生大量錯誤訊息。

#### Scenario: 長按 pause 不造成錯誤洗版
- **WHEN** 使用者長按 `p` 且 timer 已進入 paused
- **THEN** 系統 MUST 避免持續送出重複 `pause` 命令導致連續 `invalid_state` 顯示

