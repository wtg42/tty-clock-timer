# 技術規格文件 (Technical Specifications)

## 目標 Zig 版本

- **最低版本**: 0.16.0
- **開發版本**: 0.16.0-dev.1657+985a3565c
- **重要變更**: Zig 0.15.1+ 引入了重大的 I/O Overhaul（稱為 "Writergate"），大幅改變了 stdin/stdout/stderr 的 API

## I/O Overhaul (Writergate) API 變更

### 舊版 API（已移除）

```zig
// ❌ 不再支援
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();
```

### 新版 API

```zig
// ✅ 推薦方式：使用 buffer
var buffer: [1024]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&buffer);
const stdout = &stdout_writer.interface;

try stdout.print("Hello, {s}!\n", .{"world"});
try stdout.flush();  // 重要！否則可能不會立即輸出

// ✅ 不使用 buffer（較慢）
var stdout_writer = std.fs.File.stdout().writer(&.{});
const stdout = &stdout_writer.interface;
```

### Stdin 讀取

```zig
var buffer: [1024]u8 = undefined;
var stdin_reader = std.fs.File.stdin().reader(&buffer);
const stdin = &stdin_reader.interface;

const bytes_read = try stdin.readVec(&.{&buffer});
```

### Stderr 錯誤輸出

```zig
var err_buffer: [512]u8 = undefined;
var stderr_writer = std.fs.File.stderr().writer(&err_buffer);
const stderr = &stderr_writer.interface;

try stderr.print("Error: {s}\n", .{"something went wrong"});
try stderr.flush();
```

## 輸出與錯誤處理標準

### Debug 與 Production 輸出

```zig
// ✅ 開發階段：std.debug.print 用於除錯
std.debug.print("Debug: {s}\n", .{"debugging info"});

// ✅ 正式輸出：使用新的 stdout API
var stdout_writer = std.fs.File.stdout().writer(&buffer);
const stdout = &stdout_writer.interface;
try stdout.print("Program output: {s}\n", .{"data"});

// ✅ 錯誤訊息：輸出到 stderr
var stderr_writer = std.fs.File.stderr().writer(&err_buffer);
const stderr = &stderr_writer.interface;
try stderr.print("Error: {s}\n", .{"error message"});
```

### 錯誤處理原則

1. **CLI 參數錯誤** → 輸出到 stderr，返回 error code 1
2. **除錯資訊** → 使用 `std.debug.print` 或 `std.log`
3. **正常輸出** → 輸出到 stdout
4. **不使用 `unreachable`** 除錯保證的條件

## 編碼規範

### 檔案格式

- **縮排**: 4 spaces（不使用 tabs）
- **格式化**: 使用 `zig fmt src/` 在 commit 前格式化

### 命名慣例

```zig
// snake_case 用於函數和變數
const total_seconds: u32 = 1500;
pub fn parseArgs(allocator: std.mem.Allocator) !Config { ... }

// CamelCase 用於型別
pub const Config = struct { ... };
pub const TimerState = enum { idle, running, finished };

// ALL_CAPS 用於常數（選用）
const MAX_BUFFER_SIZE = 1024;
```

### 匯入順序

```zig
// 1. Zig 標準庫
const std = @import("std");

// 2. 專案模組
const tty_clock_timer = @import("tty_clock_timer");

// 3. 第三方模組（如果有）
// const some_lib = @import("some_lib");
```

### 註解規範

```zig
/// 公共 API 必須有文件註解
/// 使用範例：
/// - --minutes 25  或 -m 25  => 倒數 25 分鐘
pub const Config = struct { ... };

// 內部實作使用單行註解
var buffer: [1024]u8 = undefined; // I/O buffer
```

## 記憶體管理

### Allocator 使用原則

```zig
// ✅ Executable: 使用 GeneralPurposeAllocator
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
defer {
    const result = gpa.deinit();
    if (result == .leak) @panic("memory leak detected");
}
const allocator = gpa.allocator();

// ✅ 測試環境: 使用 std.testing.allocator
test "example test" {
    const allocator = std.testing.allocator;
    // ...
}
```

### Arena Allocator 適用情境

```zig
// ✅ 生命週期短暫的暫時性配置
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();
const arena_allocator = arena.allocator();

// 配置所有暫時性資源，一次性清理
const args = try std.process.argsAlloc(arena_allocator);
```

## 測試規範

### 測試位置

```zig
// ✅ 測試寫在實作檔案中
test "parseArgsFromSlice - valid minutes" {
    const args = &[_][]const u8{ "--minutes", "25" };
    const config = try parseArgsFromSlice(args);
    try std.testing.expectEqual(@as(u32, 1500), config.duration_seconds);
}
```

### 測試命名

- 格式：`test "functionName - description"`
- 描述要清楚說明測試的情境

## 模組架構

### 模組依賴關係

```
main.zig (CLI entry point)
  └─> root.zig (library module)
       ├─> config.zig (CLI 解析)
       ├─> timer.zig (計時核心)
       ├─> ui.zig (TTY 顯示)
       └─> notify.zig (桌面通知)
```

### Public API 暴露

```zig
// root.zig - 暴露所有公共 API
pub const config = @import("lib/config.zig");
pub const timer = @import("lib/timer.zig");
pub const ui = @import("lib/ui.zig");
pub const notify = @import("lib/notify.zig");
```

## 建置與測試指令

```bash
# 建置執行檔
zig build

# 執行應用程式
zig build run -- --minutes 25

# 執行所有測試
zig build test

# 執行 fuzz tests
zig build test --fuzz

# 格式化程式碼
zig fmt src/

# 清理建置產物
zig build clean
```

## 平台相容性

### 目標平台

- **主要支援**: Linux (x86_64)
- **Terminal 依賴**: 需支援 ANSI escape sequences
- **Notification 依賴**: `notify-send` 或同等 D-Bus 機制

### 編譯目標

```bash
# 針對特定平台建置
zig build -Dtarget=x86_64-linux-gnu

# Release 模式
zig build -Doptimize=ReleaseFast
zig build -Doptimize=ReleaseSafe
zig build -Doptimize=ReleaseSmall
```

## 效能考量

### Buffer 大小建議

```zig
// CLI 輸出: 1KB buffer
var cli_buffer: [1024]u8 = undefined;

// 錯誤訊息: 512B buffer
var err_buffer: [512]u8 = undefined;

// UI 渲染: 4KB+ buffer（視螢幕大小）
var ui_buffer: [4096]u8 = undefined;
```

### 避免

```zig
// ❌ 避免頻繁的小寫入
try stdout.write("H");
try stdout.write("e");
try stdout.write("l");
try stdout.write("l");
try stdout.write("o");

// ✅ 使用單次寫入
try stdout.print("Hello", .{});
```

## 安全性考量

### 輸入驗證

```zig
// ✅ 驗證數值範圍
const seconds = std.fmt.parseInt(u32, args[1], 10) catch {
    return ParseError.InvalidNumber;
};
if (seconds == 0) {
    return ParseError.ZeroDuration;
}
```

### 資源清理

```zig
// ✅ 確保所有資源都被清理
defer file.close();
defer allocator.free(buffer);
defer arena.deinit();
```

## 版本歷史

### v0.16.0-dev.1657+985a3565c
- I/O Overhaul（Writergate）API 變更
- `std.io.getStdOut/In/Err` 移除
- 改用 `std.fs.File.stdout/In/Err().writer/reader()`
- 新增 `interface` 欄位存取 writer/reader 方法

## 參考資料

- [Zig 0.15.1 Release Notes - Writergate](https://ziglang.org/download/0.15.1/release-notes.html)
- [Zig's New Writer](https://www.openmymind.net/Zigs-New-Writer/)
- [Zig 0.15.1 I/O Overhaul](https://medium.com/computatrum-veneficus/zig-0-15-1-i-o-overhaul-understanding-the-new-reader-writer-interfaces-38cb5bf442cc)
- [Ziggit - stdin/stdout changes](https://ziggit.dev/t/stdin-or-stdout-changed-last-night/10972)
