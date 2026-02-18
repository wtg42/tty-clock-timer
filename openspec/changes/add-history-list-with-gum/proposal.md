## Why

目前 CLI 僅支援即時輸入 minutes/seconds，重複使用常用時長時需要反覆手動輸入，流程成本偏高。團隊希望提供 `list` 子命令讓使用者可直接挑選既有歷史時長，並以 `gum` 提供更好的互動體驗，同時保留無 `gum` 環境的可用性。

## What Changes

- 新增 timer duration history 持久化機制，使用 XDG 規範儲存歷史紀錄（以 state 類型資料為主）
- 新增 `list` 子命令：顯示歷史時長並允許使用者選擇，選擇後直接啟動 timer
- 新增 `gum` optional integration：優先使用專案內建 binary，其次系統 PATH，失敗時 fallback 至內建純文字選單
- 新增 history 管理策略：去重、排序、容量上限與損壞檔案處理

## Capabilities

### New Capabilities
- `history-duration-selection`: 定義歷史時長持久化、互動選擇流程與 `gum` fallback 行為

## Impact

- `core/src/lib/config.zig`：CLI 參數模型需支援 `list` 子命令
- `core/src/main.zig`：新增 list flow、選擇後啟動與 history 寫入流程
- `core/src/lib/`（新增模組）：history storage 與 selection 協調邏輯
- `tools/gum/*`：可選 bundled gum binary 位置（若採 repo 內分發）
