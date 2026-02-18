//! Timer duration history storage and selection helpers.
const std = @import("std");
const Io = std.Io;
const Dir = std.Io.Dir;

pub const MAX_HISTORY_ENTRIES: usize = 50;

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
    defer allocator.free(entries);

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

pub fn nowUnixSeconds(io: Io) i64 {
    return std.Io.Timestamp.now(io, .real).toSeconds();
}

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
