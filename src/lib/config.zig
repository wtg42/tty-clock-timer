const std = @import("std");

pub const Config = struct {
    duration_seconds: u32,
    reset_mode: bool,
    show_help: bool,
};

pub const ParseError = error{
    MissingArguments,
    MissingMinutesValue,
    MissingSecondsValue,
    UnknownArgument,
    InvalidNumber,
};

pub fn parseArgs(allocator: std.mem.Allocator) !Config {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    return parseArgsFromSlice(args[1..]);
}

/// 核心解析邏輯 (方便寫 test)
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

// 輔助函式
fn isHelpArg(arg: []const u8) bool {
    return std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h");
}

fn isMinutesArg(arg: []const u8) bool {
    return std.mem.eql(u8, arg, "--minutes") or std.mem.eql(u8, arg, "-m");
}

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
