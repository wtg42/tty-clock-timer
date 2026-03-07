## ADDED Requirements

### Requirement: --setup-sound 必須透過 prompt helper 完成互動
系統 MUST 使用 Bun 啟動的 prompt helper 執行 `--setup-sound` 的播放器選擇與檔案輸入流程，且 MUST NOT 回退到 `gum` binary 或其他純文字互動路徑。

#### Scenario: prompt helper 無法啟動
- **WHEN** core 無法啟動 prompt helper 或 helper 回傳錯誤
- **THEN** 系統 MUST 以非零 exit code 結束
- **AND** 系統 MUST 回報可理解的錯誤訊息

## MODIFIED Requirements

### Requirement: --setup-sound 互動設定模式
系統 MUST 支援 `tic --setup-sound` 參數，進入音效設定模式。此模式 MUST NOT 啟動計時器 TUI，而是透過 prompt helper 互動引導用戶完成音效設定並寫入設定檔後退出。

#### Scenario: 正常完成設定
- **WHEN** 用戶執行 `tic --setup-sound`，選擇播放器並輸入有效音效檔路徑
- **THEN** 系統 MUST 將播放器路徑與音效檔路徑寫入設定檔，並顯示成功訊息

#### Scenario: 偵測到系統播放器
- **WHEN** 進入 `--setup-sound` 模式
- **THEN** 系統 MUST 自動偵測系統中存在的常見播放器（paplay、pw-play、aplay、mpg123、ffplay），並透過 prompt helper 列出供選擇

#### Scenario: 系統無任何播放器
- **WHEN** 進入 `--setup-sound` 模式但偵測不到任何播放器
- **THEN** 系統 MUST 仍允許用戶透過 prompt helper 手動輸入完整播放器路徑

#### Scenario: 用戶中途取消
- **WHEN** 用戶在 prompt helper 互動中主動取消
- **THEN** 系統 MUST 不修改設定檔，並以非零 exit code 退出

## REMOVED Requirements

### Requirement: gum binary 解析
**Reason**: `--setup-sound` 不再依賴 `gum` binary 解析機制，而是依賴 prompt helper artifact。
**Migration**: core 改為解析 prompt helper 路徑並以 Bun 啟動 helper。
