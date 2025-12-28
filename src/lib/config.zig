const std = @import("std");

/// CLI 參數解析模組
/// 提供命令列參數解析功能，支援 --minutes/-m、--seconds/-s、--help/-h 參數
///
/// 使用範例：
/// - --minutes 25  或 -m 25  => 倒數 25 分鐘
/// - --seconds 90  或 -s 90  => 倒數 90 秒
/// - --help       或 -h     => 顯示說明訊息
pub const Config = struct {
    /// 倒數計時持續時間（秒）
    duration_seconds: u32,
    /// 重置模式（目前未使用）
    reset_mode: bool,
    /// 是否顯示說明訊息
    show_help: bool,
};

/// CLI 參數解析錯誤類型
pub const ParseError = error{
    /// 未提供任何參數
    MissingArguments,
    /// --minutes/-m 缺少數值
    MissingMinutesValue,
    /// --seconds/-s 缺少數值
    MissingSecondsValue,
    /// 不支援的參數
    UnknownArgument,
    /// 無效的數值格式
    InvalidNumber,
};

/// 從程序實際參數解析 CLI 設定
///
/// 使用 `std.process.argsAlloc` 獲取程序參數並傳給 `parseArgsFromSlice` 處理
///
/// Parameters:
///   - allocator: 記憶體分配器，用於分配參數字串
///
/// Returns:
///   - Config: 解析成功的設定物件
///   - ParseError: 解析失敗的錯誤
pub fn parseArgs(allocator: std.mem.Allocator) !Config {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    return parseArgsFromSlice(args[1..]);
}

/// 從字串切片解析 CLI 設定（核心解析邏輯）
///
/// 此函式設計為可獨立測試，方便使用固定輸入進行單元測試
/// 支援的參數格式：
///   - --minutes <num> 或 -m <num>: 設定倒數分鐘數
///   - --seconds <num> 或 -s <num>: 設定倒數秒數
///   - --help 或 -h: 顯示說明訊息
///
/// Parameters:
///   - args: 參數字串切片（不含執行檔名稱）
///
/// Returns:
///   - Config: 解析成功的設定物件
///   - ParseError: 解析失敗的錯誤（缺少參數、無效格式等）
pub fn parseArgsFromSlice(args: []const []const u8) !Config {
    var config = Config{
        .duration_seconds = 0,
        .reset_mode = false,
        .show_help = false,
    };

    if (args.len == 0) {
        return ParseError.MissingArguments;
    }

    const first_arg = args[0];

    // 處理 help 參數
    if (isHelpArg(first_arg)) {
        config.show_help = true;
        return config;
    }

    // 處理時間參數
    if (isMinutesArg(first_arg)) {
        if (args.len < 2) {
            return ParseError.MissingMinutesValue;
        }
        const minutes = std.fmt.parseInt(u32, args[1], 10) catch {
            return ParseError.InvalidNumber;
        };
        config.duration_seconds = std.math.mul(u32, minutes, 60) catch {
            return ParseError.InvalidNumber;
        };
        return config;
    }

    if (isSecondsArg(first_arg)) {
        if (args.len < 2) {
            return ParseError.MissingSecondsValue;
        }
        const seconds = std.fmt.parseInt(u32, args[1], 10) catch {
            return ParseError.InvalidNumber;
        };
        config.duration_seconds = seconds;
        return config;
    }

    return ParseError.UnknownArgument;
}

/// 輔助函式群
/// 檢查參數字串是否符合 help flag
/// 支援：--help 和 -h
fn isHelpArg(arg: []const u8) bool {
    return std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h");
}

/// 檢查參數字串是否符合 minutes flag
/// 支援：--minutes 和 -m
fn isMinutesArg(arg: []const u8) bool {
    return std.mem.eql(u8, arg, "--minutes") or std.mem.eql(u8, arg, "-m");
}

/// 檢查參數字串是否符合 seconds flag
/// 支援：--seconds 和 -s
fn isSecondsArg(arg: []const u8) bool {
    return std.mem.eql(u8, arg, "--seconds") or std.mem.eql(u8, arg, "-s");
}

test "parseArgsFromSlice - valid minutes" {
    const args = &[_][]const u8{ "--minutes", "25" };
    const config = try parseArgsFromSlice(args);
    try std.testing.expectEqual(@as(u32, 1500), config.duration_seconds);
    try std.testing.expectEqual(false, config.reset_mode);
    try std.testing.expectEqual(false, config.show_help);
}

test "parseArgsFromSlice - valid seconds" {
    const args = &[_][]const u8{ "--seconds", "90" };
    const config = try parseArgsFromSlice(args);
    try std.testing.expectEqual(@as(u32, 90), config.duration_seconds);
    try std.testing.expectEqual(false, config.reset_mode);
    try std.testing.expectEqual(false, config.show_help);
}

test "parseArgsFromSlice - help flag" {
    const args = &[_][]const u8{"--help"};
    const config = try parseArgsFromSlice(args);
    try std.testing.expectEqual(@as(u32, 0), config.duration_seconds);
    try std.testing.expectEqual(false, config.reset_mode);
    try std.testing.expectEqual(true, config.show_help);
}

test "parseArgsFromSlice - short minutes" {
    const args = &[_][]const u8{ "-m", "5" };
    const config = try parseArgsFromSlice(args);
    try std.testing.expectEqual(@as(u32, 300), config.duration_seconds);
    try std.testing.expectEqual(false, config.reset_mode);
    try std.testing.expectEqual(false, config.show_help);
}

test "parseArgsFromSlice - short seconds" {
    const args = &[_][]const u8{ "-s", "30" };
    const config = try parseArgsFromSlice(args);
    try std.testing.expectEqual(@as(u32, 30), config.duration_seconds);
    try std.testing.expectEqual(false, config.reset_mode);
    try std.testing.expectEqual(false, config.show_help);
}

test "parseArgsFromSlice - short help" {
    const args = &[_][]const u8{"-h"};
    const config = try parseArgsFromSlice(args);
    try std.testing.expectEqual(@as(u32, 0), config.duration_seconds);
    try std.testing.expectEqual(false, config.reset_mode);
    try std.testing.expectEqual(true, config.show_help);
}

test "parseArgsFromSlice - missing arguments" {
    const args = &[_][]const u8{};
    try std.testing.expectError(ParseError.MissingArguments, parseArgsFromSlice(args));
}

test "parseArgsFromSlice - missing minutes value" {
    const args = &[_][]const u8{"--minutes"};
    try std.testing.expectError(ParseError.MissingMinutesValue, parseArgsFromSlice(args));
}

test "parseArgsFromSlice - missing seconds value" {
    const args = &[_][]const u8{"--seconds"};
    try std.testing.expectError(ParseError.MissingSecondsValue, parseArgsFromSlice(args));
}

test "parseArgsFromSlice - unknown argument" {
    const args = &[_][]const u8{"--unknown"};
    try std.testing.expectError(ParseError.UnknownArgument, parseArgsFromSlice(args));
}

test "parseArgsFromSlice - invalid number" {
    const args = &[_][]const u8{ "--minutes", "abc" };
    try std.testing.expectError(ParseError.InvalidNumber, parseArgsFromSlice(args));
}
