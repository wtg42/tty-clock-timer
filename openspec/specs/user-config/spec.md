# user-config Specification

## Purpose
TBD - synced from change sound-setup.

## Requirements

### Requirement: 用戶設定檔讀寫
系統 MUST 在 `$XDG_CONFIG_HOME/tty-clock-timer/config.json`（預設 `~/.config/tty-clock-timer/config.json`）讀寫用戶設定。設定檔 MUST 為有效 JSON，音效設定欄位為可選。

#### Scenario: 寫入音效設定
- **WHEN** `--setup-sound` 完成後
- **THEN** 系統 MUST 將 `{"sound": {"player": "<path>", "file": "<path>"}}` 寫入設定檔，若設定檔已存在則合併（不覆蓋其他欄位）

#### Scenario: 設定檔目錄不存在
- **WHEN** 寫入設定檔時目錄不存在
- **THEN** 系統 MUST 自動建立 `~/.config/tty-clock-timer/` 目錄

#### Scenario: 讀取音效設定
- **WHEN** 系統啟動計時器
- **THEN** 系統 MUST 嘗試讀取設定檔；若存在音效設定則載入，若設定檔不存在則靜默略過

#### Scenario: 設定檔格式錯誤
- **WHEN** 設定檔存在但 JSON 格式無效
- **THEN** 系統 MUST 靜默略過音效設定，不中斷正常計時功能
