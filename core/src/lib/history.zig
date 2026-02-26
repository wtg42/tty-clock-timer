//! Timer history storage and selection helpers.
//!
//! This module persists recent durations, keeps recency ordering, and supports deletion by label.

const std = @import("std");
const Io = std.Io;
const Dir = std.Io.Dir;

pub const MAX_HISTORY_ENTRIES: usize = 10;

pub const Entry = struct {
    duration_seconds: u32,
    last_used_at: i64,
};

const HistoryFile = struct {
    entries: []Entry,
};

pub const PathError = error{MissingHome} || std.mem.Allocator.Error;

pub const StorageError =
    error{InvalidHistoryFormat} ||
    Dir.ReadFileAllocError ||
    Dir.WriteFileError ||
    Dir.CreateDirPathError ||
    std.mem.Allocator.Error;

pub const SelectionResult = union(enum) {
    chosen: usize,
    canceled,
    invalid,
};

/// Resolves history.json path using XDG_STATE_HOME first, then HOME fallback.
pub fn resolveHistoryPath(
    allocator: std.mem.Allocator,
    environ_map: *const std.process.Environ.Map,
) PathError![]u8 {
    if (environ_map.get("XDG_STATE_HOME")) |xdg_state_home| {
        if (xdg_state_home.len > 0) {
            return std.fmt.allocPrint(
                allocator,
                "{s}/tty-clock-timer/history.json",
                .{xdg_state_home},
            );
        }
    }

    const home = environ_map.get("HOME") orelse return error.MissingHome;
    if (home.len == 0) return error.MissingHome;

    return std.fmt.allocPrint(
        allocator,
        "{s}/.local/state/tty-clock-timer/history.json",
        .{home},
    );
}

/// Loads and validates history entries from disk into owned memory.
pub fn loadEntries(allocator: std.mem.Allocator, io: Io, path: []const u8) StorageError![]Entry {
    const content = Dir.cwd().readFileAlloc(io, path, allocator, .limited(64 * 1024)) catch |err| switch (err) {
        error.FileNotFound => return allocator.alloc(Entry, 0),
        else => |e| return e,
    };
    defer allocator.free(content);

    if (content.len == 0) return allocator.alloc(Entry, 0);

    var parsed = std.json.parseFromSlice(std.json.Value, allocator, content, .{}) catch {
        return error.InvalidHistoryFormat;
    };
    defer parsed.deinit();

    if (parsed.value != .object) return error.InvalidHistoryFormat;
    const entries_value = parsed.value.object.get("entries") orelse return allocator.alloc(Entry, 0);
    if (entries_value != .array) return error.InvalidHistoryFormat;

    var list: std.ArrayList(Entry) = .empty;
    defer list.deinit(allocator);

    for (entries_value.array.items) |item| {
        if (item != .object) return error.InvalidHistoryFormat;
        const duration_value = item.object.get("duration_seconds") orelse return error.InvalidHistoryFormat;
        const timestamp_value = item.object.get("last_used_at") orelse return error.InvalidHistoryFormat;

        const duration_int = switch (duration_value) {
            .integer => |v| v,
            else => return error.InvalidHistoryFormat,
        };
        const timestamp_int = switch (timestamp_value) {
            .integer => |v| v,
            else => return error.InvalidHistoryFormat,
        };

        if (duration_int <= 0 or duration_int > std.math.maxInt(u32)) {
            return error.InvalidHistoryFormat;
        }

        try list.append(allocator, .{
            .duration_seconds = @intCast(duration_int),
            .last_used_at = @intCast(timestamp_int),
        });
    }

    return list.toOwnedSlice(allocator);
}

/// Persists history entries to disk, creating parent directories when needed.
pub fn saveEntries(
    allocator: std.mem.Allocator,
    io: Io,
    path: []const u8,
    entries: []const Entry,
) StorageError!void {
    const parent = std.fs.path.dirname(path) orelse return error.InvalidHistoryFormat;
    try Dir.cwd().createDirPath(io, parent);

    const payload = HistoryFile{ .entries = @constCast(entries) };
    const encoded = try std.json.Stringify.valueAlloc(allocator, payload, .{});
    defer allocator.free(encoded);

    try Dir.cwd().writeFile(io, .{
        .sub_path = path,
        .data = encoded,
    });
}

/// Records a used duration, updates recency, and enforces max history size.
pub fn recordDuration(
    allocator: std.mem.Allocator,
    io: Io,
    path: []const u8,
    duration_seconds: u32,
    now_unix_seconds: i64,
) StorageError!void {
    const entries = loadEntries(allocator, io, path) catch |err| switch (err) {
        error.InvalidHistoryFormat => try allocator.alloc(Entry, 0),
        else => |e| return e,
    };

    var list = std.ArrayList(Entry).fromOwnedSlice(entries);
    defer list.deinit(allocator);

    var found = false;
    for (list.items) |*entry| {
        if (entry.duration_seconds == duration_seconds) {
            entry.last_used_at = now_unix_seconds;
            found = true;
            break;
        }
    }

    if (!found) {
        try list.append(allocator, .{
            .duration_seconds = duration_seconds,
            .last_used_at = now_unix_seconds,
        });
    }

    sortByLastUsedDesc(list.items);
    if (list.items.len > MAX_HISTORY_ENTRIES) {
        list.shrinkRetainingCapacity(MAX_HISTORY_ENTRIES);
    }

    const normalized = try list.toOwnedSlice(allocator);
    defer allocator.free(normalized);
    try saveEntries(allocator, io, path, normalized);
}

/// Parses numeric selection input and maps it to choose/cancel/invalid.
pub fn selectionFromInput(input: []const u8, max_items: usize) SelectionResult {
    const trimmed = std.mem.trim(u8, input, " \t\r\n");
    if (trimmed.len == 0) return .canceled;
    if (std.mem.eql(u8, trimmed, "q")) return .canceled;

    const parsed = std.fmt.parseInt(usize, trimmed, 10) catch {
        return .invalid;
    };
    if (parsed == 0 or parsed > max_items) return .invalid;
    return .{ .chosen = parsed - 1 };
}

/// Returns current real Unix timestamp in seconds.
pub fn nowUnixSeconds(io: Io) i64 {
    return std.Io.Timestamp.now(io, .real).toSeconds();
}

/// Sorts entries by most recently used timestamp in descending order.
fn sortByLastUsedDesc(entries: []Entry) void {
    if (entries.len < 2) return;

    var i: usize = 0;
    while (i < entries.len) : (i += 1) {
        var j: usize = i + 1;
        while (j < entries.len) : (j += 1) {
            if (entries[j].last_used_at > entries[i].last_used_at) {
                const tmp = entries[i];
                entries[i] = entries[j];
                entries[j] = tmp;
            }
        }
    }
}

/// Builds a new entry list excluding labels selected for deletion.
pub fn deleteEntriesByLabels(
    allocator: std.mem.Allocator,
    entries: []const Entry,
    to_delete_labels: []const []const u8,
) std.mem.Allocator.Error![]Entry {
    var filtered: std.ArrayList(Entry) = .empty;
    defer filtered.deinit(allocator);

    outer: for (entries) |entry| {
        const label = try formatDurationLabel(allocator, entry.duration_seconds);
        defer allocator.free(label);

        for (to_delete_labels) |to_delete| {
            if (std.mem.eql(u8, label, to_delete)) {
                continue :outer;
            }
        }

        try filtered.append(allocator, entry);
    }

    return filtered.toOwnedSlice(allocator);
}

/// Formats duration as `MM:SS (Ns)` for history menus and matching.
fn formatDurationLabel(allocator: std.mem.Allocator, duration_seconds: u32) std.mem.Allocator.Error![]u8 {
    const minutes = duration_seconds / 60;
    const seconds = duration_seconds % 60;
    return std.fmt.allocPrint(allocator, "{d:0>2}:{d:0>2} ({d}s)", .{ minutes, seconds, duration_seconds });
}

test "history/resolveHistoryPath - prefers XDG_STATE_HOME" {
    const allocator = std.testing.allocator;
    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();

    try environ_map.put("XDG_STATE_HOME", "/tmp/xdg-state");
    try environ_map.put("HOME", "/tmp/home");

    const path = try resolveHistoryPath(allocator, &environ_map);
    defer allocator.free(path);

    try std.testing.expectEqualStrings(
        "/tmp/xdg-state/tty-clock-timer/history.json",
        path,
    );
}

test "history/resolveHistoryPath - falls back to HOME" {
    const allocator = std.testing.allocator;
    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();

    try environ_map.put("HOME", "/tmp/home");

    const path = try resolveHistoryPath(allocator, &environ_map);
    defer allocator.free(path);

    try std.testing.expectEqualStrings(
        "/tmp/home/.local/state/tty-clock-timer/history.json",
        path,
    );
}

test "history/selectionFromInput - handles choose cancel invalid" {
    try std.testing.expectEqual(
        SelectionResult{ .chosen = 1 },
        selectionFromInput("2", 3),
    );
    try std.testing.expectEqual(SelectionResult.canceled, selectionFromInput("", 3));
    try std.testing.expectEqual(SelectionResult.canceled, selectionFromInput("q", 3));
    try std.testing.expectEqual(SelectionResult.invalid, selectionFromInput("9", 3));
    try std.testing.expectEqual(SelectionResult.invalid, selectionFromInput("abc", 3));
}

test "history/deleteEntriesByLabels - delete single entry" {
    const allocator = std.testing.allocator;
    const entries = &[_]Entry{
        .{ .duration_seconds = 1500, .last_used_at = 100 },
        .{ .duration_seconds = 900, .last_used_at = 200 },
        .{ .duration_seconds = 300, .last_used_at = 150 },
    };

    const to_delete = &[_][]const u8{"25:00 (1500s)"};
    const result = try deleteEntriesByLabels(allocator, entries, to_delete);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 2), result.len);
    try std.testing.expectEqual(@as(u32, 900), result[0].duration_seconds);
    try std.testing.expectEqual(@as(u32, 300), result[1].duration_seconds);
}

test "history/deleteEntriesByLabels - delete multiple entries" {
    const allocator = std.testing.allocator;
    const entries = &[_]Entry{
        .{ .duration_seconds = 1500, .last_used_at = 100 },
        .{ .duration_seconds = 900, .last_used_at = 200 },
        .{ .duration_seconds = 300, .last_used_at = 150 },
    };

    const to_delete = &[_][]const u8{ "25:00 (1500s)", "05:00 (300s)" };
    const result = try deleteEntriesByLabels(allocator, entries, to_delete);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 1), result.len);
    try std.testing.expectEqual(@as(u32, 900), result[0].duration_seconds);
}

test "history/deleteEntriesByLabels - delete all entries" {
    const allocator = std.testing.allocator;
    const entries = &[_]Entry{
        .{ .duration_seconds = 1500, .last_used_at = 100 },
        .{ .duration_seconds = 900, .last_used_at = 200 },
    };

    const to_delete = &[_][]const u8{ "25:00 (1500s)", "15:00 (900s)" };
    const result = try deleteEntriesByLabels(allocator, entries, to_delete);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 0), result.len);
}
