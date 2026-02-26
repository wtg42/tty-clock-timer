//! JSONL IPC schema and helper APIs for core <-> TUI communication.
//!
//! Messages are serialized as one JSON object per line and routed by the `type` discriminator.

const std = @import("std");
const Io = std.Io;

/// Message type enum corresponding to Message union tags.
/// - update_timer: Periodic timer state update (remaining time, total duration, status)
/// - timer_finished: Timer countdown completed
/// - exit: Process should terminate gracefully
/// - keyboard_input: Raw keyboard input from user (e.g., "q" to quit)
/// - command: Control command sent from external process (pause, resume, reset, quit)
/// - command_result: Response to a command indicating success or failure
pub const MessageType = enum {
    init,
    update_timer,
    timer_finished,
    exit,
    keyboard_input,
    command,
    command_result,
};

pub const SoundConfig = struct {
    player: []const u8,
    file: []const u8,
};

/// Control commands that can be sent to the timer.
/// - pause: Pause the running timer
/// - resume: Resume a paused timer
/// - reset: Reset timer back to initial duration
/// - quit: Terminate the timer process
pub const Command = enum {
    pause,
    @"resume",
    reset,
    quit,

    /// Parses command text into a Command enum value when recognized.
    pub fn parse(value: []const u8) ?Command {
        inline for (std.meta.fields(Command)) |field| {
            if (std.mem.eql(u8, value, field.name)) {
                return @enumFromInt(field.value);
            }
        }
        return null;
    }

    /// Returns the command tag name as a string slice.
    pub fn asSlice(self: Command) []const u8 {
        return @tagName(self);
    }
};

/// Discriminated union representing all IPC messages.
/// Used for bidirectional communication between Core and TUI/external processes.
/// All messages are serialized to JSON with a "type" field matching the active union tag.
pub const Message = union(MessageType) {
    init: struct {
        sound: ?SoundConfig,
    },
    /// Timer state update sent periodically (~1 second intervals).
    /// Fields: current remaining time, initial duration, status, and ETA (`HH:MM`).
    update_timer: struct {
        remaining_seconds: u32,
        total_duration: u32,
        status: []const u8,
        eta_hhmm: []const u8,
    },
    /// Timer countdown completed successfully.
    timer_finished: struct {
        total_duration: u32,
    },
    /// Signal to gracefully terminate the process.
    exit: void,
    /// Raw keyboard input from user (typically "q" for quit).
    keyboard_input: struct {
        key: []const u8,
    },
    /// External control command with correlation ID for request/response tracking.
    command: struct {
        id: []const u8,
        command: []const u8,
    },
    /// Response to a previously sent command, indicating success or error.
    command_result: struct {
        id: []const u8,
        success: bool,
        @"error": ?[]const u8,
    },

    /// Serializes Message payload with a stable `type` discriminator field first.
    pub fn jsonStringify(self: Message, jws: anytype) !void {
        try jws.beginObject();
        // Always emit "type" field first
        try jws.objectField("type");
        try jws.write(@tagName(self));

        // Serialize payload fields based on message variant
        switch (self) {
            .init => |payload| {
                try jws.objectField("sound");
                try jws.write(payload.sound);
            },
            .update_timer => |payload| {
                try jws.objectField("remaining_seconds");
                try jws.write(payload.remaining_seconds);
                try jws.objectField("total_duration");
                try jws.write(payload.total_duration);
                try jws.objectField("status");
                try jws.write(payload.status);
                try jws.objectField("eta_hhmm");
                try jws.write(payload.eta_hhmm);
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

/// Errors that can occur during JSON message parsing.
/// - MissingField: Required field not found in JSON object
/// - InvalidFieldType: Field exists but has wrong JSON type (e.g., string instead of number)
/// - InvalidMessageType: "type" field value does not match any known message variant
/// - InvalidMessage: JSON structure is fundamentally invalid (not an object, etc.)
pub const ParseError = error{
    MissingField,
    InvalidFieldType,
    InvalidMessageType,
    InvalidMessage,
};

/// Frees heap-owned fields from messages produced by parseMessage.
pub fn freeMessage(allocator: std.mem.Allocator, message: Message) void {
    switch (message) {
        .update_timer => |payload| {
            allocator.free(payload.status);
            allocator.free(payload.eta_hhmm);
        },
        .init => |payload| {
            if (payload.sound) |sound| {
                allocator.free(sound.player);
                allocator.free(sound.file);
            }
        },
        .keyboard_input => |payload| allocator.free(payload.key),
        .command => |payload| {
            allocator.free(payload.id);
            allocator.free(payload.command);
        },
        .command_result => |payload| {
            allocator.free(payload.id);
            // Error message may be null (successful result), so check before freeing
            if (payload.@"error") |msg| allocator.free(msg);
        },
        else => {},
    }
}

/// Parses one JSON line into a typed Message union value.
pub fn parseMessage(allocator: std.mem.Allocator, json: []const u8) !Message {
    // Parse raw JSON into generic value tree
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json, .{});
    defer parsed.deinit();

    // Ensure root is an object
    if (parsed.value != .object) return error.InvalidMessage;

    const obj = parsed.value.object;
    // Extract and validate the "type" discriminator field
    const type_value = obj.get("type") orelse return error.MissingField;
    const type_str = switch (type_value) {
        .string => |value| value,
        else => return error.InvalidFieldType,
    };

    if (std.mem.eql(u8, type_str, "update_timer")) {
        // Extract timer state fields
        const remaining_value = obj.get("remaining_seconds") orelse return error.MissingField;
        const total_value = obj.get("total_duration") orelse return error.MissingField;
        const status_value = obj.get("status") orelse return error.MissingField;
        const eta_value = obj.get("eta_hhmm") orelse return error.MissingField;

        // Type-coerce to integers
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
        const eta_str = switch (eta_value) {
            .string => |value| value,
            else => return error.InvalidFieldType,
        };

        // Validate integers fit in u32 range
        if (remaining_int < 0 or remaining_int > std.math.maxInt(u32)) return error.InvalidFieldType;
        if (total_int < 0 or total_int > std.math.maxInt(u32)) return error.InvalidFieldType;

        return Message{ .update_timer = .{
            .remaining_seconds = @intCast(remaining_int),
            .total_duration = @intCast(total_int),
            .status = try allocator.dupe(u8, status_str),
            .eta_hhmm = try allocator.dupe(u8, eta_str),
        } };
    }

    if (std.mem.eql(u8, type_str, "init")) {
        const sound_value = obj.get("sound") orelse return error.MissingField;

        const sound: ?SoundConfig = switch (sound_value) {
            .null => null,
            .object => |sound_obj| blk: {
                const player_value = sound_obj.get("player") orelse return error.MissingField;
                const file_value = sound_obj.get("file") orelse return error.MissingField;

                const player = switch (player_value) {
                    .string => |value| value,
                    else => return error.InvalidFieldType,
                };
                const file = switch (file_value) {
                    .string => |value| value,
                    else => return error.InvalidFieldType,
                };

                break :blk .{
                    .player = try allocator.dupe(u8, player),
                    .file = try allocator.dupe(u8, file),
                };
            },
            else => return error.InvalidFieldType,
        };

        return Message{ .init = .{ .sound = sound } };
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

/// Serializes a Message and writes it as one JSON line.
pub fn sendMessage(allocator: std.mem.Allocator, writer: *Io.Writer, message: Message) !void {
    const json = try std.json.Stringify.valueAlloc(allocator, message, .{});
    defer allocator.free(json);
    try writer.writeAll(json);
    try writer.writeByte('\n');
}

/// Sends an `update_timer` event with remaining time, status, and ETA.
pub fn updateTimer(
    allocator: std.mem.Allocator,
    writer: *Io.Writer,
    remaining_seconds: u32,
    total_duration: u32,
    status: []const u8,
    eta_hhmm: []const u8,
) !void {
    try sendMessage(allocator, writer, Message{ .update_timer = .{
        .remaining_seconds = remaining_seconds,
        .total_duration = total_duration,
        .status = status,
        .eta_hhmm = eta_hhmm,
    } });
}

/// Sends an `init` event with optional sound configuration payload.
pub fn sendInit(
    allocator: std.mem.Allocator,
    writer: *Io.Writer,
    sound: ?SoundConfig,
) !void {
    try sendMessage(allocator, writer, Message{ .init = .{ .sound = sound } });
}

/// Sends a `timer_finished` event when countdown reaches zero.
pub fn notifyTimerFinished(allocator: std.mem.Allocator, writer: *Io.Writer, total_duration: u32) !void {
    try sendMessage(allocator, writer, Message{ .timer_finished = .{ .total_duration = total_duration } });
}

/// Sends an `exit` event for graceful shutdown coordination.
pub fn sendExit(allocator: std.mem.Allocator, writer: *Io.Writer) !void {
    try sendMessage(allocator, writer, Message{ .exit = {} });
}

/// Sends a `command_result` event with success state and optional error.
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

/// Checks whether keyboard input requests process quit.
pub fn handleKeyboardInput(key: []const u8) bool {
    return std.mem.eql(u8, key, "q");
}

// Test parsing a command message with id and command fields.
test "ipc/parseMessage - command roundtrip" {
    const allocator = std.testing.allocator;
    const json = "{\"type\":\"command\",\"id\":\"1\",\"command\":\"pause\"}";
    const message = try parseMessage(allocator, json);
    defer freeMessage(allocator, message);

    try std.testing.expect(message == .command);
    try std.testing.expectEqualStrings("1", message.command.id);
    try std.testing.expectEqualStrings("pause", message.command.command);
}

test "ipc/parseMessage - update_timer includes eta" {
    const allocator = std.testing.allocator;
    const json =
        "{" ++
        "\"type\":\"update_timer\"," ++
        "\"remaining_seconds\":42," ++
        "\"total_duration\":60," ++
        "\"status\":\"running\"," ++
        "\"eta_hhmm\":\"14:35\"" ++
        "}";
    const message = try parseMessage(allocator, json);
    defer freeMessage(allocator, message);

    try std.testing.expect(message == .update_timer);
    try std.testing.expectEqual(@as(u32, 42), message.update_timer.remaining_seconds);
    try std.testing.expectEqualStrings("running", message.update_timer.status);
    try std.testing.expectEqualStrings("14:35", message.update_timer.eta_hhmm);
}

test "ipc/parseMessage - init with sound" {
    const allocator = std.testing.allocator;
    const json = "{\"type\":\"init\",\"sound\":{\"player\":\"/usr/bin/paplay\",\"file\":\"/tmp/ding.wav\"}}";
    const message = try parseMessage(allocator, json);
    defer freeMessage(allocator, message);

    try std.testing.expect(message == .init);
    const sound = message.init.sound orelse {
        try std.testing.expect(false);
        return;
    };
    try std.testing.expectEqualStrings("/usr/bin/paplay", sound.player);
    try std.testing.expectEqualStrings("/tmp/ding.wav", sound.file);
}

test "ipc/parseMessage - update_timer missing eta" {
    const allocator = std.testing.allocator;
    const json =
        "{" ++
        "\"type\":\"update_timer\"," ++
        "\"remaining_seconds\":42," ++
        "\"total_duration\":60," ++
        "\"status\":\"running\"" ++
        "}";

    try std.testing.expectError(error.MissingField, parseMessage(allocator, json));
}

// Test parsing a successful command result where error field is null.
test "ipc/parseMessage - command_result with null error" {
    const allocator = std.testing.allocator;
    const json = "{\"type\":\"command_result\",\"id\":\"1\",\"success\":true,\"error\":null}";
    const message = try parseMessage(allocator, json);
    defer freeMessage(allocator, message);

    try std.testing.expect(message == .command_result);
    try std.testing.expect(message.command_result.success);
    try std.testing.expect(message.command_result.@"error" == null);
}

// Test Command.parse() correctly maps string names to enum values.
test "ipc/command parser" {
    try std.testing.expectEqual(@as(?Command, .pause), Command.parse("pause"));
    try std.testing.expectEqual(@as(?Command, .@"resume"), Command.parse("resume"));
    try std.testing.expectEqual(@as(?Command, .reset), Command.parse("reset"));
    try std.testing.expectEqual(@as(?Command, .quit), Command.parse("quit"));
    try std.testing.expectEqual(@as(?Command, null), Command.parse("invalid"));
}
