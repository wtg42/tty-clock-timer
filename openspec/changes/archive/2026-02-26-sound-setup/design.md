## Context

目前計時完畢只有 TUI 視覺動畫，沒有音效。Core（Zig）負責 CLI 參數解析與啟動 TUI；gum binary 已透過 `TTY_CLOCK_GUM_BIN` 環境變數提供，並有完整的路徑偵測機制（`findBundledGum`）。TUI 透過 IPC JSON 訊息與 Core 通訊。

## Goals / Non-Goals

**Goals:**
- 新增 `--setup-sound` 模式：透過 gum 互動收集播放器與音效檔路徑，寫入設定檔
- 啟動計時時讀取設定，透過 IPC 傳給 TUI
- TUI 在 `timer_finished` 時呼叫播放器播放音效

**Non-Goals:**
- bundle 預設音效檔（用戶自備）
- 音量控制
- 多音效 / 序列播放
- Windows / macOS 支援

## Decisions

### 決策 1：設定讀寫在 Core（Zig），不在 TUI

Core 已負責 CLI 參數解析與 gum 互動（history 選單），設定檔自然由同一層管理。TUI 保持無狀態，音效設定透過啟動 IPC 訊息傳入。

替代方案：TUI 自己讀設定檔 → 拆散設定邏輯，且 TUI 需要知道設定檔路徑，增加耦合。

### 決策 2：直接 spawn gum 指令，不寫 shell script

Core 已有 `runGumSpinnerWithArgs` 等 gum 呼叫模式，直接 spawn `gum choose` 與 `gum input` 即可，不需要額外維護 shell script。流程：
1. 偵測系統中的常見播放器（`which paplay`、`pw-play`、`aplay`、`mpg123`、`ffplay`）
2. `gum choose` 列出找到的播放器供選擇
3. `gum input --placeholder "/path/to/sound.wav"` 輸入音效檔路徑
4. 寫入 `~/.config/tty-clock-timer/config.json`

### 決策 3：設定檔格式為 JSON，路徑遵循 XDG

```json
{
  "sound": {
    "player": "/usr/bin/paplay",
    "file": "/home/user/sounds/bell.wav"
  }
}
```

路徑：`$XDG_CONFIG_HOME/tty-clock-timer/config.json`，預設 `~/.config/tty-clock-timer/config.json`。

### 決策 4：音效設定透過 IPC init 訊息傳給 TUI

在 Core 啟動 TUI 後發送的第一個訊息中附帶音效設定。TUI 儲存後在 `timer_finished` 時使用。若設定為空則靜默略過。

### 決策 5：TUI 播放音效用 `Bun.spawn`

TUI 以 `Bun.spawn([player, file])` 非同步 fire-and-forget 方式播放，失敗靜默忽略，不影響計時主流程。

## Risks / Trade-offs

- [系統無播放器] `--setup-sound` 偵測不到任何播放器 → 顯示提示訊息，引導用戶手動輸入完整路徑
- [音效檔不存在] 啟動時設定檔有路徑但檔案不存在 → TUI 播放時 spawn 失敗，靜默忽略
- [IPC 訊息擴充] 修改 init 訊息結構 → 需確保 TUI 向後相容（欄位可選）
