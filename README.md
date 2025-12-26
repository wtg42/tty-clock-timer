# TTY Clock Timer

在 Linux terminal 顯示的倒數計時器，視覺風格參考 tty-clock，核心功能為 timer。到時會觸發 desktop notification，並在 UI 上加入醒目效果。首版以 CLI 參數設定為主。

## 資料夾功能規劃
- `src/`：核心程式碼
- `src/main.zig`：CLI entry point、參數解析、程式啟動流程
- `src/lib/`：核心邏輯模組
- `src/lib/timer.zig`：倒數計時與狀態管理
- `src/lib/ui.zig`：TTY 顯示與動畫效果
- `src/lib/notify.zig`：Linux desktop notification 介面
- `src/lib/config.zig`：CLI options 與預設值定義
- `docs/`：文件
- `docs/PLAN.md`：PRD
- `docs/USAGE.md`：CLI 使用範例與行為說明
- `assets/`（可選）：字型或示意圖
