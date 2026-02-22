## Why

歷史記錄功能已經支援透過 `list` 子命令檢視和選擇時鐘時長，但無法刪除不需要的記錄。為了讓使用者能夠清理過時或錯誤的歷史項目，需要新增刪除功能。這能改善使用者體驗，讓歷史記錄保持簡潔。

## What Changes

- 為 `list` 子命令新增 `--delete` 標誌：`tty_clock_timer list --delete`
- 使用 gum 的多選介面讓使用者選擇要刪除的時鐘時長（可多選）
- 刪除選中項目後，將剩餘的歷史記錄輸出到 stdout
- 若無歷史記錄或全部刪除後，輸出「no history」訊息

## Capabilities

### New Capabilities
- `list-delete-mode`: 支援透過 `list --delete` 對歷史時鐘時長進行多選刪除

### Modified Capabilities
- `history-storage`: 歷史記錄模組需新增刪除功能（刪除指定項目並重新排序）

## Impact

- **修改檔案**: `core/src/lib/config.zig`（CLI 解析）、`core/src/main.zig`（刪除流程）、`core/src/lib/history.zig`（刪除邏輯）
- **相關系統**: 歷史記錄存儲與 gum 多選工具整合
- **API 變更**: 無 breaking changes，純粹新增子命令選項
