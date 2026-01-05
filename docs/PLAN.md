# PRD: TTY Clock Timer

## 背景與目標
本專案是一個在 Linux terminal 顯示的倒數計時器，視覺風格參考 tty-clock，但核心功能是 timer。時間到時會發送 desktop notification，並在 UI 上加入特殊效果以提高醒目度。首版只提供 CLI 參數設定，產出可用的 binary。

## 目標使用者與情境
- Linux 使用者在 terminal 中需要快速設定倒數計時（例如工作番茄鐘、料理計時）。
- 偏好輕量、免 GUI app 的工具。

## 範圍
- In scope: CLI 參數設定倒數計時、顯示 tty-clock 風格 UI、時間到 notification、reset 功能、產出 binary。
- Out of scope: 互動式輸入、pause/resume、多組 timer、跨平台支援。

## 需求與功能
- CLI
  - 基本用法：`tty_clock_timer --minutes 25` 或 `--seconds 90`
  - reset：`tty_clock_timer --reset`
- UI
  - 倒數顯示模組（ASCII/terminal glyphs）
  - 到時視覺特效（例如閃爍或反白）
- Notification
  - Linux desktop notification（例如 `notify-send` 或同等機制）

## 成功指標
- 倒數計時正確到秒。
- time up 後，terminal UI 與 desktop notification 同時出現。
- CLI 參數錯誤時給出清楚錯誤訊息。

## 里程碑（MVP）
1) CLI parsing 與 timer core ✅ 已完成 (config.zig 實作完成, timer core 待實作)
2) TTY UI 與倒數顯示 ❌ 未開始
3) time up 效果與 notification ❌ 未開始
4) 打包與 README 更新 ❌ 未開始

## 風險與假設
- 假設：目標系統可用 desktop notification（如 `notify-send`）。
- 風險：不同 terminal 對 UI 效果支援差異。

## 目前進度 (2025-01-05)

### 已完成
- **CLI 參數解析**: 完整的參數解析邏輯，支援 --minutes/-m, --seconds/-s, --help/-h
- **錯誤處理**: 全面的錯誤類型定義與處理
- **測試覆蓋**: config.zig 有完整單元測試
- **建置系統**: 標準 Zig 建置配置
- **專案架構**: 清晰的模組分層設計

### 當前狀態
- 程式可以編譯並正確解析 CLI 參數
- main.zig 目前只印出配置結果，尚未實作實際計時功能
- 缺少 timer.zig, ui.zig, notify.zig 核心模組

### 下一階段重點
1. 實作 timer.zig - 倒數計時邏輯與狀態管理
2. 實作 ui.zig - TTY 顯示與動畫效果
3. 整合主程式流程

## 後續擴充方向
- 互動式輸入與快捷鍵
- pause/resume、多組 timer
- 其他 notification channel（sound、system bell）
