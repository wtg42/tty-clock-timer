# history-duration-selection Specification

## Purpose
TBD - created by archiving change add-history-list-with-gum. Update Purpose after archive.
## Requirements
### Requirement: 系統必須持久化可重用的時長歷史
系統 MUST 在每次成功啟動 timer 後記錄該時長至 history，並將資料儲存在符合 XDG state 規範的路徑。history 記錄 MUST 具備去重與上限控制，避免無限制成長。

#### Scenario: 成功啟動後寫入歷史
- **WHEN** 使用者以任一合法方式啟動 timer（包含參數啟動或 list 選擇）
- **THEN** 系統 MUST 將對應 duration seconds 寫入 history
- **AND** 相同 duration 若已存在 MUST 更新其最近使用時間而非新增重複項目

#### Scenario: 歷史超過上限
- **WHEN** history 筆數超過系統定義上限
- **THEN** 系統 MUST 保留最近使用的紀錄並裁剪較舊項目

### Requirement: 系統必須提供 `list` 子命令供使用者選擇歷史時長
系統 MUST 提供 `tty_clock_timer list` 子命令，列出可用歷史時長並允許使用者選擇；選擇成功後 MUST 直接啟動對應 timer。

#### Scenario: 使用者選擇歷史項目
- **WHEN** 使用者執行 `tty_clock_timer list` 並選取一個歷史時長
- **THEN** 系統 MUST 使用該時長啟動 timer

#### Scenario: 歷史為空
- **WHEN** 使用者執行 `tty_clock_timer list` 但尚無歷史資料
- **THEN** 系統 MUST 顯示可理解的提示並結束 list 流程

#### Scenario: 使用者取消選擇
- **WHEN** 使用者在 list 流程中主動取消
- **THEN** 系統 MUST 結束流程且不得啟動 timer

### Requirement: 系統必須以 `gum` 優化互動並提供 fallback
系統 SHOULD 優先使用 `gum` 執行互動選單，但在 `gum` 缺失、執行失敗或逾時時 MUST 自動改用內建純文字選單，維持 `list` 可用性。

#### Scenario: `gum` 可用
- **WHEN** 系統找到可執行的 `gum` binary
- **THEN** list 流程 SHOULD 透過 `gum` 呈現選單並回傳選擇結果

#### Scenario: `gum` 不可用或失敗
- **WHEN** `gum` 不存在、執行錯誤或逾時
- **THEN** 系統 MUST 自動切換至內建純文字選單
- **AND** 使用者仍可完成選擇並啟動 timer

