//! CLI argument parsing for timer duration/help flags.
//!
//! Supported flags:
//! - `--minutes <num>` / `-m <num>`
//! - `--seconds <num>` / `-s <num>`
//! - `--help` / `-h`
const std = @import("std");

/// Parsed CLI configuration.
pub const Config = struct {
    command: Command,
    /// Countdown duration in seconds.
    duration_seconds: u32,
    /// If true, caller should print usage and exit.
    show_help: bool,
};

pub const Command = enum {
    start,
    list,
};

/// CLI parse errors surfaced to main.
pub const ParseError = error{
    /// `--minutes` / `-m` is missing value.
    MissingMinutesValue,
    /// `--seconds` / `-s` is missing value.
    MissingSecondsValue,
    /// Unknown flag.
    UnknownArgument,
    /// Value cannot be parsed as `u32`.
    InvalidNumber,
    /// Arithmetic overflow (e.g. minutes * 60 overflows `u32`).
    Overflow,
    /// Allocation failure when collecting argv.
    OutOfMemory,
};

/// Parses args from global process argv (kept for compatibility/testing).
pub fn parseArgs2(allocator: std.mem.Allocator) !Config {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    return parseArgsFromSlice(args[1..]);
}

/// Parses args using `std.process.Init.Minimal` iterator.
pub fn parseArgs(allocator: std.mem.Allocator, init: std.process.Init.Minimal) !Config {
    var argsSlice = try std.ArrayList([]const u8).initCapacity(allocator, 0);
    defer argsSlice.deinit(allocator);
    var args = init.args.iterate();
    var is_first = true;
    while (args.next()) |arg| {
        if (is_first) {
            is_first = false;
            continue;
        }
        try argsSlice.append(allocator, arg);
    }

    return parseArgsFromSlice(argsSlice.items);
}

/// Core parser from argv slice (without executable name).
pub fn parseArgsFromSlice(args: []const []const u8) !Config {
    var config = Config{
        .command = .start,
        .duration_seconds = 0,
        .show_help = false,
    };

    // Step A: No args defaults to help mode for friendlier CLI onboarding.
    if (args.len == 0) {
        config.show_help = true;
        return config;
    }

    const first_arg = args[0];

    // Step B: Explicit help has highest priority and short-circuits parsing.
    if (isHelpArg(first_arg)) {
        config.show_help = true;
        return config;
    }

    if (isListArg(first_arg)) {
        if (args.len != 1) return ParseError.UnknownArgument;
        config.command = .list;
        return config;
    }

    // Step C: Parse minutes and normalize to seconds.
    if (isMinutesArg(first_arg)) {
        if (args.len < 2) {
            return ParseError.MissingMinutesValue;
        }
        const minutes = std.fmt.parseInt(u32, args[1], 10) catch {
            return ParseError.InvalidNumber;
        };
        config.duration_seconds = std.math.mul(u32, minutes, 60) catch {
            return ParseError.Overflow;
        };
        return config;
    }

    // Step D: Parse seconds directly.
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

    // Step E: Any unmatched flag is treated as unknown input.
    return ParseError.UnknownArgument;
}

/// Returns true when `arg` is help flag.
fn isHelpArg(arg: []const u8) bool {
    return std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h");
}

/// Returns true when `arg` is minutes flag.
fn isMinutesArg(arg: []const u8) bool {
    return std.mem.eql(u8, arg, "--minutes") or std.mem.eql(u8, arg, "-m");
}

/// Returns true when `arg` is seconds flag.
fn isSecondsArg(arg: []const u8) bool {
    return std.mem.eql(u8, arg, "--seconds") or std.mem.eql(u8, arg, "-s");
}

/// Returns true when `arg` is list subcommand.
fn isListArg(arg: []const u8) bool {
    return std.mem.eql(u8, arg, "list");
}

test "parseArgsFromSlice - valid minutes" {
    const args = &[_][]const u8{ "--minutes", "25" };
    const config = try parseArgsFromSlice(args);
    try std.testing.expectEqual(Command.start, config.command);
    try std.testing.expectEqual(@as(u32, 1500), config.duration_seconds);
    try std.testing.expectEqual(false, config.show_help);
}

test "parseArgsFromSlice - valid seconds" {
    const args = &[_][]const u8{ "--seconds", "90" };
    const config = try parseArgsFromSlice(args);
    try std.testing.expectEqual(Command.start, config.command);
    try std.testing.expectEqual(@as(u32, 90), config.duration_seconds);
    try std.testing.expectEqual(false, config.show_help);
}

test "parseArgsFromSlice - help flag" {
    const args = &[_][]const u8{"--help"};
    const config = try parseArgsFromSlice(args);
    try std.testing.expectEqual(Command.start, config.command);
    try std.testing.expectEqual(@as(u32, 0), config.duration_seconds);
    try std.testing.expectEqual(true, config.show_help);
}

test "parseArgsFromSlice - short minutes" {
    const args = &[_][]const u8{ "-m", "5" };
    const config = try parseArgsFromSlice(args);
    try std.testing.expectEqual(Command.start, config.command);
    try std.testing.expectEqual(@as(u32, 300), config.duration_seconds);
    try std.testing.expectEqual(false, config.show_help);
}

test "parseArgsFromSlice - short seconds" {
    const args = &[_][]const u8{ "-s", "30" };
    const config = try parseArgsFromSlice(args);
    try std.testing.expectEqual(Command.start, config.command);
    try std.testing.expectEqual(@as(u32, 30), config.duration_seconds);
    try std.testing.expectEqual(false, config.show_help);
}

test "parseArgsFromSlice - short help" {
    const args = &[_][]const u8{"-h"};
    const config = try parseArgsFromSlice(args);
    try std.testing.expectEqual(Command.start, config.command);
    try std.testing.expectEqual(@as(u32, 0), config.duration_seconds);
    try std.testing.expectEqual(true, config.show_help);
}

test "parseArgsFromSlice - empty args shows help" {
    const args = &[_][]const u8{};
    const config = try parseArgsFromSlice(args);
    try std.testing.expectEqual(Command.start, config.command);
    try std.testing.expectEqual(@as(u32, 0), config.duration_seconds);
    try std.testing.expectEqual(true, config.show_help);
}

test "parseArgsFromSlice - list subcommand" {
    const args = &[_][]const u8{"list"};
    const config = try parseArgsFromSlice(args);
    try std.testing.expectEqual(Command.list, config.command);
    try std.testing.expectEqual(@as(u32, 0), config.duration_seconds);
    try std.testing.expectEqual(false, config.show_help);
}

test "parseArgsFromSlice - list with extra argument is invalid" {
    const args = &[_][]const u8{ "list", "extra" };
    try std.testing.expectError(ParseError.UnknownArgument, parseArgsFromSlice(args));
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

test "parseArgsFromSlice - invalid seconds number" {
    const args = &[_][]const u8{ "--seconds", "abc" };
    try std.testing.expectError(ParseError.InvalidNumber, parseArgsFromSlice(args));
}

test "parseArgsFromSlice - minutes overflow" {
    const minutes_overflow = std.math.maxInt(u32) / 60 + 1;
    const minutes_str = std.fmt.comptimePrint("{d}", .{minutes_overflow});
    const args = &[_][]const u8{ "--minutes", minutes_str };
    try std.testing.expectError(ParseError.Overflow, parseArgsFromSlice(args));
}
