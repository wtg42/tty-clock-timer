## Why

計時完畢目前只有視覺動畫，缺乏音效提示。使用者可能在背景執行計時器，無法注意到畫面，需要音效才能真正告知計時結束。

## What Changes

- 新增 `tic --setup-sound` CLI 參數：透過 gum 互動選單引導用戶選擇音效播放器與音效檔路徑，並儲存至設定檔
- 新增用戶設定檔（`~/.config/tty-clock-timer/config.json`）：持久化儲存音效播放器路徑與音效檔路徑
- 啟動時讀取設定檔，若有音效設定則透過 IPC 傳給 TUI
- TUI 在收到 `timer_finished` 事件時，使用設定的播放器播放音效檔

## Capabilities

### New Capabilities

- `sound-setup-cli`: `--setup-sound` 參數，偵測系統播放器、透過 gum 互動選單收集播放器與音效檔路徑、寫入設定檔
- `user-config`: 用戶設定檔讀寫（`~/.config/tty-clock-timer/config.json`），管理持久化設定
- `sound-playback`: TUI 在計時完畢時，根據設定呼叫系統播放器播放音效檔

### Modified Capabilities

- `cli-launch-ui`: 啟動時讀取用戶設定並透過初始 IPC 訊息傳遞音效設定給 TUI

## Impact

- `core/src/main.zig`：新增 `--setup-sound` 參數處理、設定檔讀寫、啟動時載入設定
- `core/src/lib/ipc.zig`：新增攜帶音效設定的 init 訊息欄位
- `tui/src/index.tsx`：收到 `timer_finished` 時觸發音效播放
- `tui/src/sound.ts`（新增）：音效播放邏輯，呼叫系統播放器
- 依賴：`packaging/out/appimage/AppDir/usr/lib/tty-clock-timer/tools/gum/linux-x64/gum`（已存在）
