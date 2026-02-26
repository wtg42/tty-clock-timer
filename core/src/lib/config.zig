//! CLI argument parsing for timer duration/help flags.
//!
//! Supported flags:
//! - `--minutes <num>` / `-m <num>`
//! - `--seconds <num>` / `-s <num>`
//! - `--help` / `-h`
const std = @import("std");
const Io = std.Io;
const Dir = std.Io.Dir;

const CONFIG_DIR_NAME = "tty-clock-timer";
const CONFIG_FILE_NAME = "config.json";

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
    list_delete,
    setup_sound,
};

pub const SoundConfig = struct {
    player: []const u8,
    file: []const u8,
};

pub const UserConfig = struct {
    sound: ?SoundConfig = null,
};

pub const PathError = error{MissingHome} || std.mem.Allocator.Error;

pub const StorageError =
    Dir.ReadFileAllocError ||
    Dir.WriteFileError ||
    Dir.CreateDirPathError ||
    std.mem.Allocator.Error;

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

pub fn resolveConfigPath(
    allocator: std.mem.Allocator,
    environ_map: *const std.process.Environ.Map,
) PathError![]u8 {
    if (environ_map.get("XDG_CONFIG_HOME")) |xdg_config_home| {
        if (xdg_config_home.len > 0) {
            return std.fmt.allocPrint(
                allocator,
                "{s}/{s}/{s}",
                .{ xdg_config_home, CONFIG_DIR_NAME, CONFIG_FILE_NAME },
            );
        }
    }

    const home = environ_map.get("HOME") orelse return error.MissingHome;
    if (home.len == 0) return error.MissingHome;

    return std.fmt.allocPrint(
        allocator,
        "{s}/.config/{s}/{s}",
        .{ home, CONFIG_DIR_NAME, CONFIG_FILE_NAME },
    );
}

pub fn freeUserConfig(allocator: std.mem.Allocator, config: UserConfig) void {
    if (config.sound) |sound| {
        allocator.free(sound.player);
        allocator.free(sound.file);
    }
}

pub fn readConfig(
    allocator: std.mem.Allocator,
    io: Io,
    environ_map: *const std.process.Environ.Map,
) StorageError!UserConfig {
    const config_path = resolveConfigPath(allocator, environ_map) catch {
        return .{};
    };
    defer allocator.free(config_path);

    const content = Dir.cwd().readFileAlloc(io, config_path, allocator, .limited(64 * 1024)) catch |err| switch (err) {
        error.FileNotFound => return .{},
        else => |e| return e,
    };
    defer allocator.free(content);

    if (content.len == 0) return .{};

    var parsed = std.json.parseFromSlice(std.json.Value, allocator, content, .{}) catch {
        return .{};
    };
    defer parsed.deinit();

    if (parsed.value != .object) return .{};
    const sound_value = parsed.value.object.get("sound") orelse return .{};
    if (sound_value != .object) return .{};

    const player_value = sound_value.object.get("player") orelse return .{};
    const file_value = sound_value.object.get("file") orelse return .{};

    const player = switch (player_value) {
        .string => |value| value,
        else => return .{},
    };

    const file = switch (file_value) {
        .string => |value| value,
        else => return .{},
    };

    return .{
        .sound = .{
            .player = try allocator.dupe(u8, player),
            .file = try allocator.dupe(u8, file),
        },
    };
}

pub fn writeConfig(
    allocator: std.mem.Allocator,
    io: Io,
    environ_map: *const std.process.Environ.Map,
    patch: UserConfig,
) StorageError!void {
    const config_path = resolveConfigPath(allocator, environ_map) catch {
        return;
    };
    defer allocator.free(config_path);

    const parent = std.fs.path.dirname(config_path) orelse return;
    try Dir.cwd().createDirPath(io, parent);

    const existing_content = Dir.cwd().readFileAlloc(io, config_path, allocator, .limited(64 * 1024)) catch |err| switch (err) {
        error.FileNotFound => null,
        else => |e| return e,
    };
    defer if (existing_content) |content| allocator.free(content);

    const encoded = blk: {
        if (existing_content) |content| {
            var parsed = std.json.parseFromSlice(std.json.Value, allocator, content, .{}) catch null;
            if (parsed) |*parsed_value| {
                defer parsed_value.deinit();
                var inserted_sound = false;
                if (parsed_value.value == .object and patch.sound != null) {
                    const sound = patch.sound.?;
                    var sound_obj = std.json.Value{ .object = .init(allocator) };
                    try sound_obj.object.put("player", .{ .string = sound.player });
                    try sound_obj.object.put("file", .{ .string = sound.file });
                    try parsed_value.value.object.put("sound", sound_obj);
                    inserted_sound = true;
                }
                if (parsed_value.value == .object) {
                    const encoded_existing = try std.json.Stringify.valueAlloc(allocator, parsed_value.value, .{});
                    if (inserted_sound) {
                        if (parsed_value.value.object.getPtr("sound")) |sound_ptr| {
                            if (sound_ptr.* == .object) {
                                sound_ptr.object.deinit();
                            }
                        }
                    }
                    break :blk encoded_existing;
                }
            }
        }

        const payload = UserConfig{ .sound = patch.sound };
        break :blk try std.json.Stringify.valueAlloc(allocator, payload, .{});
    };
    defer allocator.free(encoded);

    try Dir.cwd().writeFile(io, .{
        .sub_path = config_path,
        .data = encoded,
    });
}

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
        if (args.len == 1) {
            config.command = .list;
            return config;
        }
        if (args.len == 2 and isDeleteArg(args[1])) {
            config.command = .list_delete;
            return config;
        }
        return ParseError.UnknownArgument;
    }

    if (isSetupSoundArg(first_arg) and args.len == 1) {
        config.command = .setup_sound;
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

/// Returns true when `arg` is delete flag.
fn isDeleteArg(arg: []const u8) bool {
    return std.mem.eql(u8, arg, "--delete");
}

fn isSetupSoundArg(arg: []const u8) bool {
    return std.mem.eql(u8, arg, "--setup-sound");
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

test "parseArgsFromSlice - list delete subcommand" {
    const args = &[_][]const u8{ "list", "--delete" };
    const config = try parseArgsFromSlice(args);
    try std.testing.expectEqual(Command.list_delete, config.command);
    try std.testing.expectEqual(@as(u32, 0), config.duration_seconds);
    try std.testing.expectEqual(false, config.show_help);
}

test "parseArgsFromSlice - setup sound" {
    const args = &[_][]const u8{"--setup-sound"};
    const config = try parseArgsFromSlice(args);
    try std.testing.expectEqual(Command.setup_sound, config.command);
    try std.testing.expectEqual(@as(u32, 0), config.duration_seconds);
    try std.testing.expectEqual(false, config.show_help);
}

test "parseArgsFromSlice - list alone still works" {
    const args = &[_][]const u8{"list"};
    const config = try parseArgsFromSlice(args);
    try std.testing.expectEqual(Command.list, config.command);
    try std.testing.expectEqual(@as(u32, 0), config.duration_seconds);
    try std.testing.expectEqual(false, config.show_help);
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

test "config/resolveConfigPath - prefers XDG_CONFIG_HOME" {
    const allocator = std.testing.allocator;
    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();

    try environ_map.put("XDG_CONFIG_HOME", "/tmp/xdg-config");
    try environ_map.put("HOME", "/tmp/home");

    const path = try resolveConfigPath(allocator, &environ_map);
    defer allocator.free(path);

    try std.testing.expectEqualStrings(
        "/tmp/xdg-config/tty-clock-timer/config.json",
        path,
    );
}

test "config/readConfig - invalid json returns empty config" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    const config_dir = ".zig-test-config-invalid";
    const config_path = ".zig-test-config-invalid/tty-clock-timer/config.json";
    Dir.cwd().deleteTree(io, config_dir) catch {};
    defer Dir.cwd().deleteTree(io, config_dir) catch {};

    try Dir.cwd().createDirPath(io, ".zig-test-config-invalid/tty-clock-timer");
    try Dir.cwd().writeFile(io, .{
        .sub_path = config_path,
        .data = "{",
    });

    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();
    try environ_map.put("XDG_CONFIG_HOME", ".zig-test-config-invalid");

    const config = try readConfig(allocator, io, &environ_map);
    defer freeUserConfig(allocator, config);
    try std.testing.expect(config.sound == null);
}

test "config/writeConfig - merges and creates directory" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    const config_dir = ".zig-test-config-write";
    const config_path = ".zig-test-config-write/tty-clock-timer/config.json";
    Dir.cwd().deleteTree(io, config_dir) catch {};
    defer Dir.cwd().deleteTree(io, config_dir) catch {};

    try Dir.cwd().createDirPath(io, ".zig-test-config-write/tty-clock-timer");
    try Dir.cwd().writeFile(io, .{
        .sub_path = config_path,
        .data = "{\"theme\":\"light\"}",
    });

    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();
    try environ_map.put("XDG_CONFIG_HOME", ".zig-test-config-write");

    try writeConfig(allocator, io, &environ_map, .{
        .sound = .{
            .player = "/usr/bin/paplay",
            .file = "/tmp/ding.wav",
        },
    });

    const content = try Dir.cwd().readFileAlloc(io, config_path, allocator, .limited(64 * 1024));
    defer allocator.free(content);
    try std.testing.expect(std.mem.indexOf(u8, content, "\"theme\":\"light\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "\"sound\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "\"player\":\"/usr/bin/paplay\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "\"file\":\"/tmp/ding.wav\"") != null);
}
