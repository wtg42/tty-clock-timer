const std = @import("std");
const Io = std.Io;

pub const MessageType = enum {
    update_timer,
    timer_finished,
    exit,
    keyboard_input,
    command,
    command_result,
};

pub const Command = enum {
    pause,
    @"resume",
    reset,
    quit,

    pub fn parse(value: []const u8) ?Command {
        inline for (std.meta.fields(Command)) |field| {
            if (std.mem.eql(u8, value, field.name)) {
                return @enumFromInt(field.value);
            }
        }
        return null;
    }

    pub fn asSlice(self: Command) []const u8 {
        return @tagName(self);
    }
};

pub const Message = union(MessageType) {
    update_timer: struct {
        remaining_seconds: u32,
        total_duration: u32,
        status: []const u8,
    },
    timer_finished: struct {
        total_duration: u32,
    },
    exit: void,
    keyboard_input: struct {
        key: []const u8,
    },
    command: struct {
        id: []const u8,
        command: []const u8,
    },
    command_result: struct {
        id: []const u8,
        success: bool,
        @"error": ?[]const u8,
    },

    pub fn jsonStringify(self: Message, jws: anytype) !void {
        try jws.beginObject();
        try jws.objectField("type");
        try jws.write(@tagName(self));

        switch (self) {
            .update_timer => |payload| {
                try jws.objectField("remaining_seconds");
                try jws.write(payload.remaining_seconds);
                try jws.objectField("total_duration");
                try jws.write(payload.total_duration);
                try jws.objectField("status");
                try jws.write(payload.status);
            },
            .timer_finished => |payload| {
                try jws.objectField("total_duration");
                try jws.write(payload.total_duration);
            },
            .exit => {},
            .keyboard_input => |payload| {
                try jws.objectField("key");
                try jws.write(payload.key);
            },
            .command => |payload| {
                try jws.objectField("id");
                try jws.write(payload.id);
                try jws.objectField("command");
                try jws.write(payload.command);
            },
            .command_result => |payload| {
                try jws.objectField("id");
                try jws.write(payload.id);
                try jws.objectField("success");
                try jws.write(payload.success);
                try jws.objectField("error");
                try jws.write(payload.@"error");
            },
        }

        try jws.endObject();
    }
};

pub const ParseError = error{
    MissingField,
    InvalidFieldType,
    InvalidMessageType,
    InvalidMessage,
};

pub fn freeMessage(allocator: std.mem.Allocator, message: Message) void {
    switch (message) {
        .update_timer => |payload| allocator.free(payload.status),
        .keyboard_input => |payload| allocator.free(payload.key),
        .command => |payload| {
            allocator.free(payload.id);
            allocator.free(payload.command);
        },
        .command_result => |payload| {
            allocator.free(payload.id);
            if (payload.@"error") |msg| allocator.free(msg);
        },
        else => {},
    }
}

pub fn parseMessage(allocator: std.mem.Allocator, json: []const u8) !Message {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json, .{});
    defer parsed.deinit();

    if (parsed.value != .object) return error.InvalidMessage;

    const obj = parsed.value.object;
    const type_value = obj.get("type") orelse return error.MissingField;
    const type_str = switch (type_value) {
        .string => |value| value,
        else => return error.InvalidFieldType,
    };

    if (std.mem.eql(u8, type_str, "update_timer")) {
        const remaining_value = obj.get("remaining_seconds") orelse return error.MissingField;
        const total_value = obj.get("total_duration") orelse return error.MissingField;
        const status_value = obj.get("status") orelse return error.MissingField;

        const remaining_int = switch (remaining_value) {
            .integer => |value| value,
            else => return error.InvalidFieldType,
        };
        const total_int = switch (total_value) {
            .integer => |value| value,
            else => return error.InvalidFieldType,
        };
        const status_str = switch (status_value) {
            .string => |value| value,
            else => return error.InvalidFieldType,
        };

        if (remaining_int < 0 or remaining_int > std.math.maxInt(u32)) return error.InvalidFieldType;
        if (total_int < 0 or total_int > std.math.maxInt(u32)) return error.InvalidFieldType;

        return Message{ .update_timer = .{
            .remaining_seconds = @intCast(remaining_int),
            .total_duration = @intCast(total_int),
            .status = try allocator.dupe(u8, status_str),
        } };
    }

    if (std.mem.eql(u8, type_str, "timer_finished")) {
        const total_value = obj.get("total_duration") orelse return error.MissingField;
        const total_int = switch (total_value) {
            .integer => |value| value,
            else => return error.InvalidFieldType,
        };
        if (total_int < 0 or total_int > std.math.maxInt(u32)) return error.InvalidFieldType;

        return Message{ .timer_finished = .{ .total_duration = @intCast(total_int) } };
    }

    if (std.mem.eql(u8, type_str, "exit")) {
        return Message{ .exit = {} };
    }

    if (std.mem.eql(u8, type_str, "keyboard_input")) {
        const key_value = obj.get("key") orelse return error.MissingField;
        const key_str = switch (key_value) {
            .string => |value| value,
            else => return error.InvalidFieldType,
        };

        return Message{ .keyboard_input = .{ .key = try allocator.dupe(u8, key_str) } };
    }

    if (std.mem.eql(u8, type_str, "command")) {
        const id_value = obj.get("id") orelse return error.MissingField;
        const command_value = obj.get("command") orelse return error.MissingField;
        const id_str = switch (id_value) {
            .string => |value| value,
            else => return error.InvalidFieldType,
        };
        const command_str = switch (command_value) {
            .string => |value| value,
            else => return error.InvalidFieldType,
        };

        return Message{ .command = .{
            .id = try allocator.dupe(u8, id_str),
            .command = try allocator.dupe(u8, command_str),
        } };
    }

    if (std.mem.eql(u8, type_str, "command_result")) {
        const id_value = obj.get("id") orelse return error.MissingField;
        const success_value = obj.get("success") orelse return error.MissingField;
        const error_value = obj.get("error") orelse return error.MissingField;

        const id_str = switch (id_value) {
            .string => |value| value,
            else => return error.InvalidFieldType,
        };
        const success = switch (success_value) {
            .bool => |value| value,
            else => return error.InvalidFieldType,
        };
        const err_msg: ?[]const u8 = switch (error_value) {
            .null => null,
            .string => |value| try allocator.dupe(u8, value),
            else => return error.InvalidFieldType,
        };

        return Message{ .command_result = .{
            .id = try allocator.dupe(u8, id_str),
            .success = success,
            .@"error" = err_msg,
        } };
    }

    return error.InvalidMessageType;
}

pub fn sendMessage(allocator: std.mem.Allocator, writer: *Io.Writer, message: Message) !void {
    const json = try std.json.Stringify.valueAlloc(allocator, message, .{});
    defer allocator.free(json);
    try writer.writeAll(json);
    try writer.writeByte('\n');
}

pub fn receiveAndFilterMessage(allocator: std.mem.Allocator, reader: *Io.Reader) !Message {
    const line = try reader.takeDelimiter('\n') orelse return error.EndOfInput;
    if (parseMessage(allocator, line)) |msg| {
        return msg;
    } else |_| {
        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        if (std.mem.eql(u8, trimmed, "q")) {
            return Message{ .keyboard_input = .{ .key = try allocator.dupe(u8, "q") } };
        }
        return error.InvalidInput;
    }
}

pub fn updateTimer(
    allocator: std.mem.Allocator,
    writer: *Io.Writer,
    remaining_seconds: u32,
    total_duration: u32,
    status: []const u8,
) !void {
    const status_dup = try allocator.dupe(u8, status);
    defer allocator.free(status_dup);
    try sendMessage(allocator, writer, Message{ .update_timer = .{
        .remaining_seconds = remaining_seconds,
        .total_duration = total_duration,
        .status = status_dup,
    } });
}

pub fn notifyTimerFinished(allocator: std.mem.Allocator, writer: *Io.Writer, total_duration: u32) !void {
    try sendMessage(allocator, writer, Message{ .timer_finished = .{ .total_duration = total_duration } });
}

pub fn sendExit(allocator: std.mem.Allocator, writer: *Io.Writer) !void {
    try sendMessage(allocator, writer, Message{ .exit = {} });
}

pub fn sendCommandResult(
    allocator: std.mem.Allocator,
    writer: *Io.Writer,
    id: []const u8,
    success: bool,
    error_message: ?[]const u8,
) !void {
    try sendMessage(allocator, writer, Message{ .command_result = .{
        .id = id,
        .success = success,
        .@"error" = error_message,
    } });
}

pub fn handleKeyboardInput(key: []const u8) bool {
    return std.mem.eql(u8, key, "q");
}

test "ipc/parseMessage - command roundtrip" {
    const allocator = std.testing.allocator;
    const json = "{\"type\":\"command\",\"id\":\"1\",\"command\":\"pause\"}";
    const message = try parseMessage(allocator, json);
    defer freeMessage(allocator, message);

    try std.testing.expectEqual(message, .command);
    try std.testing.expectEqualStrings("1", message.command.id);
    try std.testing.expectEqualStrings("pause", message.command.command);
}

test "ipc/parseMessage - command_result with null error" {
    const allocator = std.testing.allocator;
    const json = "{\"type\":\"command_result\",\"id\":\"1\",\"success\":true,\"error\":null}";
    const message = try parseMessage(allocator, json);
    defer freeMessage(allocator, message);

    try std.testing.expectEqual(message, .command_result);
    try std.testing.expect(message.command_result.success);
    try std.testing.expect(message.command_result.@"error" == null);
}

test "ipc/command parser" {
    try std.testing.expectEqual(@as(?Command, .pause), Command.parse("pause"));
    try std.testing.expectEqual(@as(?Command, .@"resume"), Command.parse("resume"));
    try std.testing.expectEqual(@as(?Command, .reset), Command.parse("reset"));
    try std.testing.expectEqual(@as(?Command, .quit), Command.parse("quit"));
    try std.testing.expectEqual(@as(?Command, null), Command.parse("invalid"));
}
