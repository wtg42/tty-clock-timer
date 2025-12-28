# 里程碑 1：CLI Parsing 與 Timer Core

## 目標
實作 CLI 參數解析與計時器核心邏輯，產出可執行的基本倒數計時功能。

## 檔案結構

```
src/
├── main.zig           # CLI entry point（重寫）
├── root.zig           # Library module 導出（修改）
└── lib/               # 新建目錄
    ├── config.zig     # CLI options 與參數解析
    └── timer.zig      # Timer 核心邏輯
```

## CLI 規格

| 參數 | 短參數 | 說明 |
|------|--------|------|
| `--minutes` | `-m` | 設定倒數分鐘數（預設 25）|
| `--seconds` | `-s` | 設定倒數秒數 |
| `--reset` | `-r` | Reset 模式（placeholder） |
| `--help` | `-h` | 顯示使用說明 |

## 資料結構設計

### Config (config.zig)
```zig
pub const Config = struct {
    duration_seconds: u32,
    reset_mode: bool,
    show_help: bool,
};

pub const ConfigError = error{
    MissingValue,
    InvalidNumber,
    ConflictingOptions,
    UnknownOption,
    ZeroDuration,
};
```

### Timer (timer.zig)
```zig
pub const TimerState = enum { idle, running, finished };

pub const Timer = struct {
    total_seconds: u32,
    remaining_seconds: u32,
    state: TimerState,
    start_timestamp: ?i64,

    // Methods: create(), start(), update(), isFinished(), getFormattedTime(), reset()
};
```

## 實作步驟

### Step 1: 建立目錄結構
- 建立 `src/lib/` 目錄
- 建立 `src/lib/config.zig` 與 `src/lib/timer.zig`
- 更新 `src/root.zig` 導出新模組

### Step 2: 實作 config.zig
- 定義 `Config` struct 與 `ConfigError`
- 實作 `parseArgsFromSlice()`（可測試版本）
- 實作 `parseArgs()` 包裝 std.process
- 實作 `formatError()` 與 `printUsage()`
- 撰寫測試案例

### Step 3: 實作 timer.zig
- 定義 `TimerState` enum 與 `Timer` struct
- 實作 `create()`, `start()`, `reset()`
- 實作 `update()` 基於 timestamp 計算剩餘時間
- 實作 `getFormattedTime()` 與 `isFinished()`
- 撰寫測試案例

### Step 4: 整合 main.zig
- 清除範例程式碼
- 整合 config 與 timer
- 實作錯誤處理
- 實作簡單主迴圈（文字輸出，TTY UI 留待里程碑 2）

### Step 5: 驗證與清理
- `zig build test` 全部通過
- `zig fmt src/` 格式化
- 測試 CLI 各種情境

## 驗證標準
- `zig build run -- --help` 顯示使用說明
- `zig build run -- --minutes 1` 開始倒數
- `zig build run -- --seconds abc` 顯示錯誤訊息
- `zig build test` 全部通過

## 關鍵檔案
- `src/lib/config.zig` - 新建
- `src/lib/timer.zig` - 新建
- `src/root.zig` - 修改
- `src/main.zig` - 重寫
