## MODIFIED Requirements

### Requirement: OpenTUI 使用 in-process RPC 發送命令
系統 MUST 提供 Node 進程內的 Hono command endpoint，讓 OpenTUI 可透過 in-process `fetch/RPC` 發送控制命令，而不直接耦合底層 IPC transport。命令來源 MUST 來自已辨識的使用者鍵盤事件，且 MUST NOT 由未解析的原始 stdin 片段直接觸發。

#### Scenario: UI 發送 pause 命令
- **WHEN** 使用者在 OpenTUI 觸發 pause 動作
- **THEN** UI MUST 透過 Hono command endpoint 發送 `pause` 命令並收到可判讀的成功回應

#### Scenario: 無按鍵時不應有命令請求
- **WHEN** 倒數執行中未收到使用者控制鍵事件
- **THEN** Hono command endpoint MUST NOT 收到由輸入噪音產生的命令請求

### Requirement: 命令回應語意一致
系統 MUST 對 command plane 回應統一結構，至少區分成功與失敗，且失敗時 MUST 回傳可供 UI 顯示或判斷的錯誤資訊。系統 MUST 在短時間重複不合法命令情境下提供抑制策略，避免可見錯誤洗版。

#### Scenario: Core 拒絕不合法命令
- **WHEN** UI 發送目前狀態不允許的命令（例如重複 pause）
- **THEN** Hono command endpoint MUST 回傳一致格式的失敗結果與錯誤代碼/訊息

#### Scenario: 長按導致重複命令時維持可讀性
- **WHEN** 使用者持續按壓導致同一不合法命令短時間重複送出
- **THEN** UI 層 MUST 具備抑制策略以避免錯誤訊息連續覆寫造成畫面可讀性下降
