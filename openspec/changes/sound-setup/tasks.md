## 1. Core：用戶設定檔讀寫

- [ ] 1.1 建立 `core/src/lib/config.zig`：定義設定檔結構（`SoundConfig`、`UserConfig`），實作 XDG 路徑解析
- [ ] 1.2 實作 `readConfig`：讀取 JSON 設定檔，格式錯誤或不存在時回傳空設定
- [ ] 1.3 實作 `writeConfig`：合併寫入設定檔，不存在時自動建立目錄
- [ ] 1.4 為 config.zig 撰寫單元測試

## 2. Core：--setup-sound 互動模式

- [ ] 2.1 在 `core/src/main.zig` 新增 `--setup-sound` CLI 參數解析
- [ ] 2.2 實作播放器偵測：依序 `which paplay pw-play aplay mpg123 ffplay`，收集存在的播放器列表
- [ ] 2.3 呼叫 `gum choose` 列出偵測到的播放器（若無則允許手動輸入完整路徑）
- [ ] 2.4 呼叫 `gum input --placeholder "/path/to/sound.wav"` 收集音效檔路徑
- [ ] 2.5 呼叫 `writeConfig` 寫入設定，顯示成功訊息後退出（不啟動計時器 TUI）

## 3. Core：啟動時載入設定並傳給 TUI

- [ ] 3.1 在 `core/src/lib/ipc.zig` 的初始訊息中新增可選的 `sound` 欄位（`player`、`file`）
- [ ] 3.2 在 `core/src/main.zig` 啟動計時器時讀取設定，將音效設定注入初始 IPC 訊息

## 4. TUI：接收音效設定並在計時完畢時播放

- [ ] 4.1 在 `tui/src/protocol.ts` 新增 IPC 初始訊息的 `sound` 欄位型別定義
- [ ] 4.2 在 `tui/src/store.ts` 儲存音效設定至 store state
- [ ] 4.3 建立 `tui/src/sound.ts`：實作 `playSound(player, file)` 以 `Bun.spawn` fire-and-forget 播放，失敗靜默
- [ ] 4.4 在 `tui/src/index.tsx` 的 `timer_finished` 處理邏輯中呼叫 `playSound`
