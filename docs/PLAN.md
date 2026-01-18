# TTY Clock Timer - 專案計畫

## 專案目標
Linux terminal 倒數計時器，tty-clock 風格 UI，支援 desktop notification。

## 核心功能
- CLI: `--minutes 25` / `--seconds 90`
- 7-segment 倒數顯示
- 時間到視覺特效 + notification

## 當前狀態 (2026-01-18)
### ✅ 已完成
- CLI 參數解析 (config.zig)
- Timer 核心邏輯 (timer.zig)
- 記憶體管理 (allocator.zig)
- 建置系統

### 🚧 進行中
- IPC 模組 (ui.zig → ipc.zig 重構中)

### ❌ 待完成
- Notification (notify.zig)
- 主程式整合

## UI 重構計畫 - OpenTUI 整合

### 架構
```
tty_clock_timer (單一執行檔)
├── Zig 主程序 (CLI + Timer + IPC)
└── Embedded Node.js SEA (OpenTUI UI)
```

### 技術方案
- **UI**: Node.js + OpenTUI
- **通訊**: JSON via stdout/stdin
- **打包**: Zig embedFile + Node.js SEA
- **部署**: 單一執行檔

### IPC 協議
```json
{"type": "update_timer", "remaining_seconds": 1500}
{"type": "timer_finished", "total_duration": 1500}
{"type": "exit"}
```

### 優缺點
**優點**: 單一執行檔、現代化 UI、易除錯
**挑戰**: 檔案大小增加 (~20-50MB)、啟動時間

### 實作里程碑
- **Phase 1 (1-2天)**: OpenTUI 原型 + JSON IPC
- **Phase 1a**: ui.zig → ipc.zig 重構
- **Phase 2 (1天)**: Node.js SEA 建置
- **Phase 3 (2-3天)**: Zig IPC + binary embedding
- **Phase 4 (1-2天)**: 測試與優化

### 替代方案
- Bun (更小 runtime ~10MB)
- QuickJS (輕量引擎 ~1MB)
- 壓縮技術

## MVP 里程碑
1. ✅ CLI + Timer core
2. 🚧 OpenTUI 整合
3. ❌ Time up 效果 + notification
4. ❌ 打包與文件

## 風險假設
- 假設: 系統支援 `notify-send`
- 風險: terminal UI 效果差異

## 後續擴充
- 互動式輸入
- pause/resume
- 多組 timer
- sound notification
