//! tty_clock_timer CLI entrypoint.
//!
//! Responsibilities:
//! - Parse CLI arguments and initialize countdown timer state.
//! - Spawn OpenTUI child process when available and bridge IPC via Unix socket.
//! - Handle fallback keyboard input (`q`) when no UI socket is connected.
//! - Emit timer projection events (`update_timer`, `timer_finished`, `exit`).
const std = @import("std");
const Io = std.Io;
const Dir = std.Io.Dir;
const conf = @import("lib/config.zig");
const history = @import("lib/history.zig");
const ipc = @import("lib/ipc.zig");
const timer_mod = @import("lib/timer.zig");

const SOCKET_BIND_RETRY_LIMIT: u8 = 8;
const MAX_UI_CWD_CANDIDATES: usize = 5;
const DEFAULT_UI_ENTRY = "src/index.tsx";
const GUM_BINARY_ENV = "TTY_CLOCK_GUM_BIN";
const GUM_DEBUG_ENV = "TTY_CLOCK_DEBUG_GUM";
const SOCKET_PATH_FORMAT = "/tmp/tty-clock-timer-{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}.sock";

const GumSelection = union(enum) {
    chosen: u32,
    canceled,
    failed,
};

const GumMultiSelection = union(enum) {
    chosen: [][]const u8,
    canceled,
    failed,
};

const UiRuntimeContract = struct {
    cwd: []const u8,
    entry: []const u8,
};

const UiCwdCandidates = struct {
    items: [MAX_UI_CWD_CANDIDATES][]const u8 = undefined,
    len: usize = 0,

    fn append(self: *UiCwdCandidates, candidate: []const u8) void {
        if (candidate.len == 0) return;
        if (self.len >= self.items.len) return;
        self.items[self.len] = candidate;
        self.len += 1;
    }

    fn asSlice(self: *const UiCwdCandidates) []const []const u8 {
        return self.items[0..self.len];
    }
};

fn helpMessage() []const u8 {
    return "Usage: tic [OPTIONS]\n" ++
        "\n" ++
        "Options:\n" ++
        "  -m, --minutes <num>    Set countdown minutes\n" ++
        "  -s, --seconds <num>    Set countdown seconds\n" ++
        "      list               Select from history durations\n" ++
        "      list --delete      Delete history durations\n" ++
        "  -h, --help             Show this help message\n" ++
        "\n" ++
        "Example:\n" ++
        "  tic --minutes 25\n" ++
        "  tic -s 90\n" ++
        "  tic list\n" ++
        "  tic list --delete\n";
}

fn timerStateToStatus(state: timer_mod.TimerState) []const u8 {
    return switch (state) {
        .idle => "idle",
        .running => "running",
        .paused => "paused",
        .finished => "finished",
    };
}

const EtaProjection = struct {
    frozen_epoch_seconds: ?u64 = null,
};

fn currentRealEpochSeconds(io: Io) u64 {
    const now_seconds = Io.Clock.real.now(io).toSeconds();
    return if (now_seconds < 0) 0 else @intCast(now_seconds);
}

fn resolveEtaEpochSeconds(
    state: timer_mod.TimerState,
    remaining_seconds: u32,
    now_epoch_seconds: u64,
    eta_projection: *EtaProjection,
) u64 {
    const base_seconds = now_epoch_seconds;
    const computed = std.math.add(u64, base_seconds, remaining_seconds) catch std.math.maxInt(u64);

    if (state == .paused) {
        if (eta_projection.frozen_epoch_seconds) |frozen| return frozen;
        eta_projection.frozen_epoch_seconds = computed;
        return computed;
    }

    eta_projection.frozen_epoch_seconds = computed;
    return computed;
}

fn formatEtaHhmm(buffer: *[5]u8, epoch_seconds: u64) []const u8 {
    const day_seconds = (std.time.epoch.EpochSeconds{ .secs = epoch_seconds }).getDaySeconds();
    return std.fmt.bufPrint(
        buffer,
        "{d:0>2}:{d:0>2}",
        .{ day_seconds.getHoursIntoDay(), day_seconds.getMinutesIntoHour() },
    ) catch unreachable;
}

/// Maps CLI parse errors to user-facing messages.
fn configErrorMessage(err: conf.ParseError) []const u8 {
    return switch (err) {
        conf.ParseError.MissingMinutesValue => "Error: --minutes requires a numeric value\n",
        conf.ParseError.MissingSecondsValue => "Error: --seconds requires a numeric value\n",
        conf.ParseError.UnknownArgument => "Error: Unknown argument. Use --help for usage information\n",
        conf.ParseError.InvalidNumber => "Error: Invalid numeric value provided\n",
        conf.ParseError.Overflow => "Error: Numeric value too large\n",
        conf.ParseError.OutOfMemory => "Error: Out of memory\n",
    };
}

fn formatDurationLabel(allocator: std.mem.Allocator, duration_seconds: u32) ![]u8 {
    const minutes = duration_seconds / 60;
    const seconds = duration_seconds % 60;
    return std.fmt.allocPrint(allocator, "{d:0>2}:{d:0>2} ({d}s)", .{ minutes, seconds, duration_seconds });
}

fn bundledGumPathCandidates() []const []const u8 {
    const builtin = @import("builtin");
    return switch (builtin.os.tag) {
        .macos => switch (builtin.cpu.arch) {
            .aarch64 => &[_][]const u8{
                "packaging/tools/gum/darwin-arm64/gum",
                "../packaging/tools/gum/darwin-arm64/gum",
                "../../packaging/tools/gum/darwin-arm64/gum",
                "tools/gum/darwin-arm64/gum",
                "../tools/gum/darwin-arm64/gum",
                "../../tools/gum/darwin-arm64/gum",
            },
            .x86_64 => &[_][]const u8{
                "packaging/tools/gum/darwin-x64/gum",
                "../packaging/tools/gum/darwin-x64/gum",
                "../../packaging/tools/gum/darwin-x64/gum",
                "tools/gum/darwin-x64/gum",
                "../tools/gum/darwin-x64/gum",
                "../../tools/gum/darwin-x64/gum",
            },
            else => &[_][]const u8{},
        },
        .linux => switch (builtin.cpu.arch) {
            .aarch64 => &[_][]const u8{
                "packaging/tools/gum/linux-arm64/gum",
                "../packaging/tools/gum/linux-arm64/gum",
                "../../packaging/tools/gum/linux-arm64/gum",
                "tools/gum/linux-arm64/gum",
                "../tools/gum/linux-arm64/gum",
                "../../tools/gum/linux-arm64/gum",
            },
            .x86_64 => &[_][]const u8{
                "packaging/tools/gum/linux-x64/gum",
                "../packaging/tools/gum/linux-x64/gum",
                "../../packaging/tools/gum/linux-x64/gum",
                "tools/gum/linux-x64/gum",
                "../tools/gum/linux-x64/gum",
                "../../tools/gum/linux-x64/gum",
            },
            else => &[_][]const u8{},
        },
        else => &[_][]const u8{},
    };
}

fn pathExists(io: Io, path: []const u8) bool {
    const file = Dir.cwd().openFile(io, path, .{}) catch return false;
    file.close(io);
    return true;
}

fn gumBinaryFromEnv(environ_map: *const std.process.Environ.Map) ?[]const u8 {
    const value = environ_map.get(GUM_BINARY_ENV) orelse return null;
    if (value.len == 0) return null;
    return value;
}

fn findAvailableGumBinary(
    io: Io,
    environ_map: *const std.process.Environ.Map,
    candidates: []const []const u8,
) ?[]const u8 {
    if (gumBinaryFromEnv(environ_map)) |env_path| {
        if (pathExists(io, env_path)) return env_path;
    }

    for (candidates) |candidate| {
        if (pathExists(io, candidate)) return candidate;
    }

    return null;
}

fn findBundledGum(io: Io, environ_map: *const std.process.Environ.Map) ?[]const u8 {
    return findAvailableGumBinary(io, environ_map, bundledGumPathCandidates());
}

fn gumDebugEnabled(environ_map: *const std.process.Environ.Map) bool {
    const value = environ_map.get(GUM_DEBUG_ENV) orelse return false;
    return std.mem.eql(u8, value, "1") or
        std.mem.eql(u8, value, "true") or
        std.mem.eql(u8, value, "yes");
}

fn appendArgOwned(
    allocator: std.mem.Allocator,
    args: *std.ArrayList([]const u8),
    owned: *std.ArrayList([]u8),
    value: []const u8,
) !void {
    const duped = try allocator.dupe(u8, value);
    try owned.append(allocator, duped);
    try args.append(allocator, duped);
}

fn chooseWithGum(
    allocator: std.mem.Allocator,
    io: Io,
    environ_map: *const std.process.Environ.Map,
    stderr_writer: *Io.Writer,
    entries: []const history.Entry,
) !GumSelection {
    if (!std.process.can_spawn) return .failed;

    var labels: std.ArrayList([]u8) = .empty;
    defer {
        for (labels.items) |label| allocator.free(label);
        labels.deinit(allocator);
    }

    try labels.ensureTotalCapacity(allocator, entries.len);
    for (entries) |entry| {
        try labels.append(allocator, try formatDurationLabel(allocator, entry.duration_seconds));
    }

    var argv_owned: std.ArrayList([]u8) = .empty;
    defer {
        for (argv_owned.items) |value| allocator.free(value);
        argv_owned.deinit(allocator);
    }

    var argv_list: std.ArrayList([]const u8) = .empty;
    defer argv_list.deinit(allocator);

    const gum_binary = findBundledGum(io, environ_map) orelse "gum";
    try appendArgOwned(allocator, &argv_list, &argv_owned, gum_binary);
    try appendArgOwned(allocator, &argv_list, &argv_owned, "choose");
    try appendArgOwned(allocator, &argv_list, &argv_owned, "--header");
    try appendArgOwned(allocator, &argv_list, &argv_owned, "Select timer duration");
    try appendArgOwned(allocator, &argv_list, &argv_owned, "--cursor");
    try appendArgOwned(allocator, &argv_list, &argv_owned, "> ");
    for (labels.items) |label| {
        try appendArgOwned(allocator, &argv_list, &argv_owned, label);
    }

    var child = std.process.spawn(io, .{
        .argv = argv_list.items,
        .stdin = .inherit,
        .stdout = .pipe,
        .stderr = .inherit,
    }) catch |err| {
        if (gumDebugEnabled(environ_map)) {
            stderr_writer.print("Debug: gum spawn failed ({s})\n", .{@errorName(err)}) catch {};
            stderr_writer.flush() catch {};
        }
        return .failed;
    };
    defer child.kill(io);

    var gum_stdout_buffer: [1024]u8 = undefined;
    var gum_stdout_reader = child.stdout.?.readerStreaming(io, &gum_stdout_buffer);
    const gum_stdout = gum_stdout_reader.interface.allocRemaining(allocator, .limited(4096)) catch |err| {
        if (gumDebugEnabled(environ_map)) {
            stderr_writer.print("Debug: gum stdout read failed ({s})\n", .{@errorName(err)}) catch {};
            stderr_writer.flush() catch {};
        }
        return .failed;
    };
    defer allocator.free(gum_stdout);

    const term = child.wait(io) catch |err| {
        if (gumDebugEnabled(environ_map)) {
            stderr_writer.print("Debug: gum wait failed ({s})\n", .{@errorName(err)}) catch {};
            stderr_writer.flush() catch {};
        }
        return .failed;
    };

    switch (term) {
        .exited => |code| {
            if (code != 0) {
                const trimmed_stdout = std.mem.trim(u8, gum_stdout, " \t\r\n");

                if (code == 130) {
                    if (gumDebugEnabled(environ_map)) {
                        stderr_writer.print("Debug: gum canceled (exit code={d})\n", .{code}) catch {};
                        stderr_writer.flush() catch {};
                    }
                    return .canceled;
                }

                if (code == 1 and trimmed_stdout.len == 0) {
                    if (gumDebugEnabled(environ_map)) {
                        stderr_writer.print("Debug: gum canceled (exit code={d})\n", .{code}) catch {};
                        stderr_writer.flush() catch {};
                    }
                    return .canceled;
                }

                if (gumDebugEnabled(environ_map)) {
                    stderr_writer.print(
                        "Debug: gum failed (exit code={d}, stdout_bytes={d})\n",
                        .{ code, gum_stdout.len },
                    ) catch {};
                    stderr_writer.flush() catch {};
                }
                return .failed;
            }
        },
        .signal => |signal| {
            if (signal == std.posix.SIG.INT) {
                if (gumDebugEnabled(environ_map)) {
                    stderr_writer.print("Debug: gum canceled (signal=INT)\n", .{}) catch {};
                    stderr_writer.flush() catch {};
                }
                return .canceled;
            }
            if (gumDebugEnabled(environ_map)) {
                stderr_writer.print("Debug: gum failed (signal={s})\n", .{@tagName(signal)}) catch {};
                stderr_writer.flush() catch {};
            }
            return .failed;
        },
        else => {
            if (gumDebugEnabled(environ_map)) {
                stderr_writer.print("Debug: gum failed (non-exit termination)\n", .{}) catch {};
                stderr_writer.flush() catch {};
            }
            return .failed;
        },
    }

    const selected = std.mem.trim(u8, gum_stdout, " \t\r\n");
    if (selected.len == 0) return .canceled;

    for (labels.items, entries) |label, entry| {
        if (std.mem.eql(u8, selected, label)) return .{ .chosen = entry.duration_seconds };
    }
    if (gumDebugEnabled(environ_map)) {
        stderr_writer.print("Debug: gum failed (unknown selection=\"{s}\")\n", .{selected}) catch {};
        stderr_writer.flush() catch {};
    }
    return .failed;
}

fn deleteWithGum(
    allocator: std.mem.Allocator,
    io: Io,
    environ_map: *const std.process.Environ.Map,
    stderr_writer: *Io.Writer,
    entries: []const history.Entry,
) !GumMultiSelection {
    if (!std.process.can_spawn) return .failed;

    var labels: std.ArrayList([]u8) = .empty;
    defer {
        for (labels.items) |label| allocator.free(label);
        labels.deinit(allocator);
    }

    try labels.ensureTotalCapacity(allocator, entries.len);
    for (entries) |entry| {
        try labels.append(allocator, try formatDurationLabel(allocator, entry.duration_seconds));
    }

    var argv_owned: std.ArrayList([]u8) = .empty;
    defer {
        for (argv_owned.items) |value| allocator.free(value);
        argv_owned.deinit(allocator);
    }

    var argv_list: std.ArrayList([]const u8) = .empty;
    defer argv_list.deinit(allocator);

    const gum_binary = findBundledGum(io, environ_map) orelse "gum";
    try appendArgOwned(allocator, &argv_list, &argv_owned, gum_binary);
    try appendArgOwned(allocator, &argv_list, &argv_owned, "choose");
    try appendArgOwned(allocator, &argv_list, &argv_owned, "--no-limit");
    try appendArgOwned(allocator, &argv_list, &argv_owned, "--header");
    try appendArgOwned(allocator, &argv_list, &argv_owned, "Select durations to delete");
    try appendArgOwned(allocator, &argv_list, &argv_owned, "--cursor");
    try appendArgOwned(allocator, &argv_list, &argv_owned, "> ");
    for (labels.items) |label| {
        try appendArgOwned(allocator, &argv_list, &argv_owned, label);
    }

    var child = std.process.spawn(io, .{
        .argv = argv_list.items,
        .stdin = .inherit,
        .stdout = .pipe,
        .stderr = .inherit,
    }) catch |err| {
        if (gumDebugEnabled(environ_map)) {
            stderr_writer.print("Debug: gum spawn failed ({s})\n", .{@errorName(err)}) catch {};
            stderr_writer.flush() catch {};
        }
        return .failed;
    };
    defer child.kill(io);

    var gum_stdout_buffer: [4096]u8 = undefined;
    var gum_stdout_reader = child.stdout.?.readerStreaming(io, &gum_stdout_buffer);
    const gum_stdout = gum_stdout_reader.interface.allocRemaining(allocator, .limited(16384)) catch |err| {
        if (gumDebugEnabled(environ_map)) {
            stderr_writer.print("Debug: gum stdout read failed ({s})\n", .{@errorName(err)}) catch {};
            stderr_writer.flush() catch {};
        }
        return .failed;
    };
    defer allocator.free(gum_stdout);

    const term = child.wait(io) catch |err| {
        if (gumDebugEnabled(environ_map)) {
            stderr_writer.print("Debug: gum wait failed ({s})\n", .{@errorName(err)}) catch {};
            stderr_writer.flush() catch {};
        }
        return .failed;
    };

    switch (term) {
        .exited => |code| {
            if (code != 0) {
                const trimmed_stdout = std.mem.trim(u8, gum_stdout, " \t\r\n");

                if (code == 130) {
                    if (gumDebugEnabled(environ_map)) {
                        stderr_writer.print("Debug: gum canceled (exit code={d})\n", .{code}) catch {};
                        stderr_writer.flush() catch {};
                    }
                    return .canceled;
                }

                if (code == 1 and trimmed_stdout.len == 0) {
                    if (gumDebugEnabled(environ_map)) {
                        stderr_writer.print("Debug: gum canceled (exit code={d})\n", .{code}) catch {};
                        stderr_writer.flush() catch {};
                    }
                    return .canceled;
                }

                if (gumDebugEnabled(environ_map)) {
                    stderr_writer.print(
                        "Debug: gum failed (exit code={d}, stdout_bytes={d})\n",
                        .{ code, gum_stdout.len },
                    ) catch {};
                    stderr_writer.flush() catch {};
                }
                return .failed;
            }
        },
        .signal => |signal| {
            if (signal == std.posix.SIG.INT) {
                if (gumDebugEnabled(environ_map)) {
                    stderr_writer.print("Debug: gum canceled (signal=INT)\n", .{}) catch {};
                    stderr_writer.flush() catch {};
                }
                return .canceled;
            }
            if (gumDebugEnabled(environ_map)) {
                stderr_writer.print("Debug: gum failed (signal={s})\n", .{@tagName(signal)}) catch {};
                stderr_writer.flush() catch {};
            }
            return .failed;
        },
        else => {
            if (gumDebugEnabled(environ_map)) {
                stderr_writer.print("Debug: gum failed (non-exit termination)\n", .{}) catch {};
                stderr_writer.flush() catch {};
            }
            return .failed;
        },
    }

    const selected = std.mem.trim(u8, gum_stdout, " \t\r\n");
    if (selected.len == 0) return .canceled;

    var selected_labels: std.ArrayList([]const u8) = .empty;
    defer selected_labels.deinit(allocator);

    var line_iter = std.mem.splitSequence(u8, selected, "\n");
    while (line_iter.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len > 0) {
            const owned = try allocator.dupe(u8, trimmed);
            try selected_labels.append(allocator, owned);
        }
    }

    if (selected_labels.items.len == 0) return .canceled;

    return .{ .chosen = try selected_labels.toOwnedSlice(allocator) };
}

fn chooseWithFallback(
    allocator: std.mem.Allocator,
    io: Io,
    stdout_writer: *Io.Writer,
    entries: []const history.Entry,
) !?u32 {
    var stdin_buffer: [1024]u8 = undefined;
    var stdin_reader: Io.File.Reader = .initStreaming(.stdin(), io, &stdin_buffer);

    while (true) {
        try stdout_writer.print("History durations:\n", .{});
        var index: usize = 0;
        while (index < entries.len) : (index += 1) {
            const label = try formatDurationLabel(allocator, entries[index].duration_seconds);
            defer allocator.free(label);
            try stdout_writer.print("  {d}. {s}\n", .{ index + 1, label });
        }
        try stdout_writer.print("Select an item (1-{d}) or q to cancel: ", .{entries.len});
        try stdout_writer.flush();

        const line = stdin_reader.interface.takeDelimiter('\n') catch |err| switch (err) {
            error.ReadFailed => return null,
            error.StreamTooLong => {
                try stdout_writer.print("Input too long. Try again.\n", .{});
                continue;
            },
        } orelse return null;

        const selection = history.selectionFromInput(line, entries.len);
        switch (selection) {
            .canceled => return null,
            .invalid => {
                try stdout_writer.print("Invalid selection.\n", .{});
                continue;
            },
            .chosen => |chosen| return entries[chosen].duration_seconds,
        }
    }
}

fn resolveDurationFromHistory(
    allocator: std.mem.Allocator,
    io: Io,
    stdout_writer: *Io.Writer,
    stderr_writer: *Io.Writer,
    environ_map: *const std.process.Environ.Map,
) !?u32 {
    const history_path = history.resolveHistoryPath(allocator, environ_map) catch return null;
    defer allocator.free(history_path);

    const entries = history.loadEntries(allocator, io, history_path) catch |err| switch (err) {
        error.InvalidHistoryFormat => {
            try stderr_writer.print(
                "Warning: History file is invalid; starting with empty history ({s})\n",
                .{history_path},
            );
            try stderr_writer.flush();
            return null;
        },
        else => return err,
    };
    defer allocator.free(entries);

    if (entries.len == 0) {
        try stdout_writer.print("No history entries found. Start a timer first.\n", .{});
        try stdout_writer.flush();
        return null;
    }

    switch (try chooseWithGum(allocator, io, environ_map, stderr_writer, entries)) {
        .chosen => |selected| return selected,
        .canceled => return null,
        .failed => {},
    }

    return try chooseWithFallback(allocator, io, stdout_writer, entries);
}

fn resolveDeletionFromHistory(
    allocator: std.mem.Allocator,
    io: Io,
    stdout_writer: *Io.Writer,
    stderr_writer: *Io.Writer,
    environ_map: *const std.process.Environ.Map,
) !void {
    const history_path = history.resolveHistoryPath(allocator, environ_map) catch {
        try stdout_writer.print("no history\n", .{});
        try stdout_writer.flush();
        return;
    };
    defer allocator.free(history_path);

    const entries = history.loadEntries(allocator, io, history_path) catch |err| switch (err) {
        error.InvalidHistoryFormat => {
            try stdout_writer.print("no history\n", .{});
            try stdout_writer.flush();
            return;
        },
        else => return err,
    };
    defer allocator.free(entries);

    if (entries.len == 0) {
        try stdout_writer.print("no history\n", .{});
        try stdout_writer.flush();
        return;
    }

    switch (try deleteWithGum(allocator, io, environ_map, stderr_writer, entries)) {
        .chosen => |selected_labels| {
            defer {
                for (selected_labels) |label| allocator.free(label);
                allocator.free(selected_labels);
            }

            const remaining = try history.deleteEntriesByLabels(allocator, entries, selected_labels);
            defer allocator.free(remaining);

            history.saveEntries(allocator, io, history_path, remaining) catch |err| {
                try stderr_writer.print("Error: Failed to save history ({s})\n", .{@errorName(err)});
                try stderr_writer.flush();
                return;
            };

            if (remaining.len == 0) {
                try stdout_writer.print("no history\n", .{});
            } else {
                var index: usize = 0;
                while (index < remaining.len) : (index += 1) {
                    const label = try formatDurationLabel(allocator, remaining[index].duration_seconds);
                    defer allocator.free(label);
                    try stdout_writer.print("{s}\n", .{label});
                }
            }
        },
        .canceled => {
            try stdout_writer.print("no history\n", .{});
        },
        .failed => {
            try stderr_writer.print("Error: gum selection failed\n", .{});
            try stderr_writer.flush();
        },
    }

    try stdout_writer.flush();
}

/// Consumes buffered stdin input and returns `true` when quit is requested.
fn handleStdinInput(allocator: std.mem.Allocator, reader: *Io.Reader, stdin_is_tty: bool) !bool {
    while (true) {
        const buffered = reader.buffered();
        if (buffered.len == 0) return false;

        const newline_index = std.mem.findScalarPos(u8, buffered, 0, '\n') orelse {
            if (stdin_is_tty and buffered[0] == 'q') {
                reader.toss(1);
                return true;
            }
            return false;
        };

        const line = buffered[0..newline_index];
        reader.toss(newline_index + 1);
        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        if (trimmed.len == 0) continue;
        if (std.mem.eql(u8, trimmed, "q")) return true;

        const parsed = ipc.parseMessage(allocator, trimmed) catch |err| {
            if (err == error.OutOfMemory) return err;
            continue;
        };
        defer ipc.freeMessage(allocator, parsed);
        switch (parsed) {
            .keyboard_input => |payload| if (ipc.handleKeyboardInput(payload.key)) return true,
            else => {},
        }
    }
}

/// Sends the current timer projection to the selected output stream.
fn sendTimerProjection(
    allocator: std.mem.Allocator,
    io: Io,
    writer: *Io.Writer,
    timer: *timer_mod.CountdownTimer,
    total_duration_seconds: u32,
    timer_finished_notified: *bool,
    eta_projection: *EtaProjection,
) !void {
    const finished = timer.isFinished();
    if (finished) {
        if (!timer_finished_notified.*) {
            try ipc.notifyTimerFinished(allocator, writer, total_duration_seconds);
            try writer.flush();
            timer_finished_notified.* = true;
        }
        return;
    }

    const remaining_seconds = @as(u32, @intCast(timer.remaining_ns / std.time.ns_per_s));
    const eta_epoch_seconds = resolveEtaEpochSeconds(
        timer.state,
        remaining_seconds,
        currentRealEpochSeconds(io),
        eta_projection,
    );
    var eta_buffer: [5]u8 = undefined;
    const eta_hhmm = formatEtaHhmm(&eta_buffer, eta_epoch_seconds);

    try ipc.updateTimer(
        allocator,
        writer,
        remaining_seconds,
        total_duration_seconds,
        timerStateToStatus(timer.state),
        eta_hhmm,
    );
    try writer.flush();
}

/// Removes stale Unix socket file if it exists.
fn clearSocketPath(io: Io, path: []const u8) !void {
    Dir.cwd().deleteFile(io, path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
}

/// Applies a parsed IPC command and reports command_result to UI.
fn applyCommand(
    allocator: std.mem.Allocator,
    io: Io,
    timer: *timer_mod.CountdownTimer,
    total_duration_seconds: u32,
    timer_finished_notified: *bool,
    eta_projection: *EtaProjection,
    writer: *Io.Writer,
    command_id: []const u8,
    command: ipc.Command,
) !bool {
    var success = true;
    var error_message: ?[]const u8 = null;
    var should_exit = false;

    switch (command) {
        .pause => {
            if (timer.state != .running) {
                success = false;
                error_message = "invalid_state";
            } else {
                timer.pause(io);
            }
        },
        .@"resume" => {
            if (timer.state != .paused) {
                success = false;
                error_message = "invalid_state";
            } else {
                try timer.unpause(io);
            }
        },
        .reset => {
            timer.reset();
            try timer.start(io);
            timer_finished_notified.* = false;
        },
        .quit => {
            should_exit = true;
        },
    }

    try ipc.sendCommandResult(allocator, writer, command_id, success, error_message);
    try writer.flush();

    if (!should_exit) {
        try sendTimerProjection(
            allocator,
            io,
            writer,
            timer,
            total_duration_seconds,
            timer_finished_notified,
            eta_projection,
        );
    }

    return should_exit;
}

/// Processes buffered IPC lines and executes commands from UI.
fn handleSocketCommands(
    allocator: std.mem.Allocator,
    io: Io,
    timer: *timer_mod.CountdownTimer,
    total_duration_seconds: u32,
    timer_finished_notified: *bool,
    eta_projection: *EtaProjection,
    reader: *Io.Reader,
    writer: *Io.Writer,
) !bool {
    while (true) {
        const buffered = reader.buffered();
        if (buffered.len == 0) return false;

        const newline_index = std.mem.findScalarPos(u8, buffered, 0, '\n') orelse return false;
        const line = buffered[0..newline_index];
        reader.toss(newline_index + 1);

        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        if (trimmed.len == 0) continue;

        const parsed = ipc.parseMessage(allocator, trimmed) catch |err| {
            if (err == error.OutOfMemory) return err;
            continue;
        };
        defer ipc.freeMessage(allocator, parsed);

        switch (parsed) {
            .command => |payload| {
                const command = ipc.Command.parse(payload.command) orelse {
                    try ipc.sendCommandResult(allocator, writer, payload.id, false, "unknown_command");
                    try writer.flush();
                    continue;
                };

                if (try applyCommand(
                    allocator,
                    io,
                    timer,
                    total_duration_seconds,
                    timer_finished_notified,
                    eta_projection,
                    writer,
                    payload.id,
                    command,
                )) {
                    return true;
                }
            },
            else => {},
        }
    }
}

/// Context for raw mode terminal settings management.
const RawModeContext = struct {
    original_termios: ?std.posix.termios,
    stdin_is_tty: bool,
};

/// Set stdin to raw mode (no echo, no canonical input) for single-key input (`q`).
/// Returns a context for restoration via defer.
fn setupRawMode(stderr_writer: *Io.Writer) !RawModeContext {
    var original_termios: ?std.posix.termios = null;
    const stdin_handle = Io.File.stdin().handle;
    const stdin_termios = std.posix.tcgetattr(stdin_handle) catch |err| switch (err) {
        error.NotATerminal => null,
        else => {
            try stderr_writer.print("Error: Failed to read stdin settings ({s})\n", .{@errorName(err)});
            try stderr_writer.flush();
            std.process.exit(1);
        },
    };
    if (stdin_termios) |current| {
        var raw = current;
        raw.lflag.ECHO = false;
        raw.lflag.ICANON = false;
        std.posix.tcsetattr(stdin_handle, .NOW, raw) catch |err| {
            try stderr_writer.print("Error: Failed to set stdin settings ({s})\n", .{@errorName(err)});
            try stderr_writer.flush();
            std.process.exit(1);
        };
        original_termios = current;
    }
    return RawModeContext{
        .original_termios = original_termios,
        .stdin_is_tty = stdin_termios != null,
    };
}

/// Resolves AppImage runtime TUI location from APPDIR contract.
fn resolveAppImageUiCwdCandidate(
    environ_map: *const std.process.Environ.Map,
    buffer: []u8,
) ?[]const u8 {
    const appdir = environ_map.get("APPDIR") orelse return null;
    if (appdir.len == 0) return null;
    return std.fmt.bufPrint(buffer, "{s}/usr/lib/tty-clock-timer/tui", .{appdir}) catch null;
}

/// Collects ordered TUI cwd candidates according to artifact contract.
fn collectUiCwdCandidates(
    environ_map: *const std.process.Environ.Map,
    appdir_candidate: ?[]const u8,
) UiCwdCandidates {
    var candidates = UiCwdCandidates{};
    if (environ_map.get("TTY_CLOCK_TUI_CWD")) |override| {
        candidates.append(override);
    }
    if (appdir_candidate) |candidate| {
        candidates.append(candidate);
    }
    const local_fallbacks = [_][]const u8{ "tui", "../tui", "../../tui" };
    for (local_fallbacks) |fallback| {
        candidates.append(fallback);
    }
    return candidates;
}

/// Resolve TUI working directory from contract candidates.
fn findUiCwd(io: Io, candidates: []const []const u8) ?[]const u8 {
    for (candidates) |candidate| {
        if (Dir.cwd().openDir(io, candidate, .{})) |dir| {
            dir.close(io);
            return candidate;
        } else |_| {}
    }
    return null;
}

/// Resolves TUI entry path from artifact contract.
fn resolveUiEntry(environ_map: *const std.process.Environ.Map) []const u8 {
    return environ_map.get("TTY_CLOCK_TUI_ENTRY") orelse DEFAULT_UI_ENTRY;
}

/// Validates contract entry exists within resolved TUI runtime cwd.
fn uiEntryExists(io: Io, cwd: []const u8, entry: []const u8) bool {
    var dir = Dir.cwd().openDir(io, cwd, .{}) catch return false;
    defer dir.close(io);

    const file = dir.openFile(io, entry, .{}) catch return false;
    file.close(io);
    return true;
}

/// Reports missing runtime artifact diagnostics.
fn printMissingUiArtifactError(stderr_writer: *Io.Writer, candidates: []const []const u8) !void {
    try stderr_writer.print(
        "Error: Missing TUI runtime artifact (contract cwd unresolved)\n",
        .{},
    );
    if (candidates.len == 0) {
        try stderr_writer.print("Attempted runtime locations: <none>\n", .{});
    } else {
        try stderr_writer.print("Attempted runtime locations:\n", .{});
        for (candidates) |candidate| {
            try stderr_writer.print("  - {s}\n", .{candidate});
        }
    }
    try stderr_writer.print(
        "Hint: set TTY_CLOCK_TUI_CWD or package APPDIR/usr/lib/tty-clock-timer/tui\n",
        .{},
    );
}

/// Reports invalid runtime entry diagnostics.
fn printInvalidUiEntryError(stderr_writer: *Io.Writer, cwd: []const u8, entry: []const u8) !void {
    try stderr_writer.print(
        "Error: Invalid TUI runtime entry (contract entry unresolved)\n",
        .{},
    );
    try stderr_writer.print("Runtime cwd: {s}\n", .{cwd});
    try stderr_writer.print("Configured entry: {s}\n", .{entry});
    try stderr_writer.print(
        "Hint: set TTY_CLOCK_TUI_ENTRY to a valid file under the runtime cwd\n",
        .{},
    );
}

/// Allows UI child a brief graceful shutdown window, then reaps/forces cleanup.
fn teardownUiChild(io: Io, child: *std.process.Child) void {
    const grace = Io.Clock.Duration{ .clock = .awake, .raw = Io.Duration.fromMilliseconds(300) };
    Io.Clock.Duration.sleep(grace, io) catch {};

    _ = child.wait(io) catch {
        child.kill(io);
    };
}

/// Context for Unix socket server management.
const SocketServerContext = struct {
    server: std.Io.net.Server,
    socket_path: []u8,
};

/// Generates per-execution unique socket path for IPC.
fn generateSocketPath(allocator: std.mem.Allocator, io: Io) ![]u8 {
    var random_bytes: [8]u8 = undefined;
    io.random(&random_bytes);
    return std.fmt.allocPrint(
        allocator,
        SOCKET_PATH_FORMAT,
        .{
            random_bytes[0],
            random_bytes[1],
            random_bytes[2],
            random_bytes[3],
            random_bytes[4],
            random_bytes[5],
            random_bytes[6],
            random_bytes[7],
        },
    );
}

/// Prepare Unix socket server for TUI <-> core IPC bridge.
/// Handles stale files and retries on path conflict.
fn setupSocket(allocator: std.mem.Allocator, io: Io, stderr_writer: *Io.Writer) !SocketServerContext {
    var attempts: u8 = 0;
    while (attempts < SOCKET_BIND_RETRY_LIMIT) : (attempts += 1) {
        const socket_path = try generateSocketPath(allocator, io);
        errdefer allocator.free(socket_path);

        clearSocketPath(io, socket_path) catch |err| {
            try stderr_writer.print("Error: Failed to clear stale socket ({s})\n", .{@errorName(err)});
            try stderr_writer.flush();
            std.process.exit(1);
        };

        const socket_address = std.Io.net.UnixAddress.init(socket_path) catch |err| {
            try stderr_writer.print("Error: Invalid socket path ({s})\n", .{@errorName(err)});
            try stderr_writer.flush();
            std.process.exit(1);
        };

        const server = std.Io.net.UnixAddress.listen(&socket_address, io, .{}) catch |err| switch (err) {
            error.AddressInUse => {
                clearSocketPath(io, socket_path) catch {};
                continue;
            },
            else => {
                try stderr_writer.print("Error: Failed to listen on unix socket ({s})\n", .{@errorName(err)});
                try stderr_writer.flush();
                std.process.exit(1);
            },
        };

        return SocketServerContext{
            .server = server,
            .socket_path = socket_path,
        };
    }

    try stderr_writer.print(
        "Error: Failed to allocate unique socket path after {d} attempts\n",
        .{SOCKET_BIND_RETRY_LIMIT},
    );
    try stderr_writer.flush();
    std.process.exit(1);
}

/// Main event loop: poll stdin/socket, handle commands, advance timer, emit updates.
fn runEventLoop(
    allocator: std.mem.Allocator,
    io: Io,
    stderr_writer: *Io.Writer,
    stdout_writer: *Io.Writer,
    stdin_is_tty: bool,
    stdin_reader: *Io.Reader,
    socket_reader: *Io.Reader,
    socket_writer: *Io.Writer,
    countdown_timer: *timer_mod.CountdownTimer,
    total_duration_seconds: u32,
    timer_finished_notified: *bool,
    eta_projection: *EtaProjection,
    socket_stream: *?std.Io.net.Stream,
    tick_duration: std.Io.Clock.Duration,
) void {
    const SOCKET_FD_INDEX = 1;

    while (true) {
        var pollfds: [2]std.posix.pollfd = undefined;
        var poll_count: usize = 0;
        const read_stdin = socket_stream.* == null;

        // Add stdin to poll when no socket connected
        if (read_stdin) {
            pollfds[0] = .{
                .fd = Io.File.stdin().handle,
                .events = std.posix.POLL.IN,
                .revents = 0,
            };
            poll_count += 1;
        }

        if (socket_stream.*) |stream| {
            pollfds[poll_count] = .{
                .fd = stream.socket.handle,
                .events = std.posix.POLL.IN,
                .revents = 0,
            };
            poll_count += 1;
        }

        if (poll_count > 0) {
            _ = std.posix.poll(pollfds[0..poll_count], 0) catch |err| {
                stderr_writer.print("Error: Failed to poll descriptors ({s})\n", .{@errorName(err)}) catch {};
                stderr_writer.flush() catch {};
                std.process.exit(1);
            };
        }

        if (read_stdin and poll_count > 0 and (pollfds[0].revents & std.posix.POLL.IN) != 0) {
            stdin_reader.fillMore() catch |err| switch (err) {
                error.EndOfStream => {},
                error.ReadFailed => {
                    stderr_writer.print("Error: Failed to read stdin ({s})\n", .{@errorName(err)}) catch {};
                    stderr_writer.flush() catch {};
                    std.process.exit(1);
                },
            };
        }

        if (socket_stream.* != null and poll_count > 0) {
            // Socket is at index 1 if stdin is polled, index 0 otherwise
            const socket_index: usize = if (read_stdin) SOCKET_FD_INDEX else 0;
            if ((pollfds[socket_index].revents & std.posix.POLL.IN) != 0) {
                socket_reader.fillMore() catch |err| switch (err) {
                    error.EndOfStream => {
                        if (socket_stream.*) |stream| {
                            var copy = stream;
                            copy.close(io);
                        }
                        socket_stream.* = null;
                    },
                    error.ReadFailed => {
                        stderr_writer.print("Error: Failed to read socket ({s})\n", .{@errorName(err)}) catch {};
                        stderr_writer.flush() catch {};
                        std.process.exit(1);
                    },
                };
            }
        }

        if (stdin_reader.bufferedLen() > 0) {
            // Fallback command path when TUI socket is unavailable.
            if (handleStdinInput(allocator, stdin_reader, stdin_is_tty) catch false) {
                if (socket_stream.* != null) {
                    ipc.sendExit(allocator, socket_writer) catch {};
                    socket_writer.flush() catch {};
                }
                return;
            }
        }

        if (socket_stream.* != null and socket_reader.bufferedLen() > 0) {
            // Primary command path from TUI command plane.
            if (handleSocketCommands(
                allocator,
                io,
                countdown_timer,
                total_duration_seconds,
                timer_finished_notified,
                eta_projection,
                socket_reader,
                socket_writer,
            ) catch false) {
                ipc.sendExit(allocator, socket_writer) catch {};
                socket_writer.flush() catch {};
                return;
            }
        }

        countdown_timer.update(io);

        if (socket_stream.*) |_| {
            sendTimerProjection(
                allocator,
                io,
                socket_writer,
                countdown_timer,
                total_duration_seconds,
                timer_finished_notified,
                eta_projection,
            ) catch |err| {
                stderr_writer.print("Error: Failed to send socket timer event ({s})\n", .{@errorName(err)}) catch {};
                stderr_writer.flush() catch {};
                std.process.exit(1);
            };
        } else {
            sendTimerProjection(
                allocator,
                io,
                stdout_writer,
                countdown_timer,
                total_duration_seconds,
                timer_finished_notified,
                eta_projection,
            ) catch |err| {
                stderr_writer.print("Error: Failed to send timer event ({s})\n", .{@errorName(err)}) catch {};
                stderr_writer.flush() catch {};
                std.process.exit(1);
            };
        }

        Io.Clock.Duration.sleep(tick_duration, io) catch |err| {
            stderr_writer.print("Error: Failed to sleep ({s})\n", .{@errorName(err)}) catch {};
            stderr_writer.flush() catch {};
            std.process.exit(1);
        };
    }
}

pub fn main(init: std.process.Init) !void {
    // Step 1: Use allocator provided by std.process.Init.
    const allocator = init.gpa;

    // Step 2: Use Io context provided by std.process.Init.
    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    var stderr_buffer: [1024]u8 = undefined;
    var stderr_file_writer: Io.File.Writer = .init(.stderr(), io, &stderr_buffer);
    const stderr_writer = &stderr_file_writer.interface;

    // Step 3: Parse CLI arguments and fail fast on invalid input.
    const config = conf.parseArgs(allocator, init.minimal) catch |err| {
        try stdout_writer.print("{s}", .{configErrorMessage(err)});
        try stdout_writer.flush();
        std.process.exit(1);
    };

    if (config.show_help) {
        // Help path (explicit `--help` or empty args): print and exit cleanly.
        try stdout_writer.print("{s}", .{helpMessage()});
        try stdout_writer.flush();
        return;
    }

    if (config.command == .list_delete) {
        try resolveDeletionFromHistory(
            allocator,
            io,
            stdout_writer,
            stderr_writer,
            init.environ_map,
        );
        return;
    }

    const total_duration_seconds = switch (config.command) {
        .start => config.duration_seconds,
        .list => (try resolveDurationFromHistory(
            allocator,
            io,
            stdout_writer,
            stderr_writer,
            init.environ_map,
        )) orelse return,
        .list_delete => unreachable,
    };
    const total_duration_ns = @as(u64, total_duration_seconds) * std.time.ns_per_s;

    // Step 4: Configure stdin into raw mode for timer runtime.
    // This lets us react to single-key input (`q`) without waiting for Enter.
    const raw_mode = try setupRawMode(stderr_writer);
    const stdin_is_tty = raw_mode.stdin_is_tty;
    defer if (raw_mode.original_termios) |saved| {
        std.posix.tcsetattr(Io.File.stdin().handle, .NOW, saved) catch |err| {
            stderr_writer.print("Error: Failed to restore stdin settings ({s})\n", .{@errorName(err)}) catch {};
            stderr_writer.flush() catch {};
        };
    };

    // Step 5: Initialize and start the timer state machine.
    var countdown_timer = timer_mod.CountdownTimer.init(total_duration_ns);
    countdown_timer.start(io) catch |err| {
        try stderr_writer.print("Error: Failed to start timer ({s})\n", .{@errorName(err)});
        try stderr_writer.flush();
        std.process.exit(1);
    };

    const maybe_history_path = history.resolveHistoryPath(allocator, init.environ_map) catch null;
    defer if (maybe_history_path) |path| allocator.free(path);
    if (maybe_history_path) |path| {
        history.recordDuration(
            allocator,
            io,
            path,
            total_duration_seconds,
            history.nowUnixSeconds(io),
        ) catch |err| {
            try stderr_writer.print(
                "Warning: Failed to persist history ({s})\n",
                .{@errorName(err)},
            );
            try stderr_writer.flush();
        };
    }

    var ui_child: ?std.process.Child = null;
    defer if (ui_child) |*child| teardownUiChild(io, child);

    var socket_server: ?std.Io.net.Server = null;
    var socket_path: ?[]u8 = null;
    var socket_stream: ?std.Io.net.Stream = null;
    defer {
        if (socket_stream) |stream| {
            var copy = stream;
            copy.close(io);
        }
        if (socket_server) |*server| server.deinit(io);
        if (socket_path) |path| {
            clearSocketPath(io, path) catch {};
            allocator.free(path);
        }
    }

    // Step 6: Resolve TUI runtime contract (cwd + entry).
    var appdir_ui_cwd_storage: [std.fs.max_path_bytes]u8 = undefined;
    const appdir_ui_cwd = resolveAppImageUiCwdCandidate(init.environ_map, &appdir_ui_cwd_storage);
    const ui_candidates = collectUiCwdCandidates(init.environ_map, appdir_ui_cwd);
    const ui_cwd = findUiCwd(io, ui_candidates.asSlice());
    const ui_entry = resolveUiEntry(init.environ_map);

    var ui_runtime: ?UiRuntimeContract = null;
    if (std.process.can_spawn) {
        if (ui_cwd) |cwd| {
            if (uiEntryExists(io, cwd, ui_entry)) {
                ui_runtime = UiRuntimeContract{
                    .cwd = cwd,
                    .entry = ui_entry,
                };
            } else {
                printInvalidUiEntryError(stderr_writer, cwd, ui_entry) catch {};
                stderr_writer.flush() catch {};
            }
        } else {
            printMissingUiArtifactError(stderr_writer, ui_candidates.asSlice()) catch {};
            stderr_writer.flush() catch {};
        }
    }

    if (std.process.can_spawn and ui_runtime != null) {
        // Step 7: Prepare Unix socket server for TUI <-> core IPC bridge.
        const server_ctx = try setupSocket(allocator, io, stderr_writer);
        socket_server = server_ctx.server;
        socket_path = server_ctx.socket_path;
    }

    if (std.process.can_spawn) {
        if (ui_runtime) |runtime| {
            const path = socket_path orelse unreachable;

            // Step 8: Spawn TUI child process and inject per-run socket path argument.
            const ui_argv = &[_][]const u8{
                "bun",
                "run",
                runtime.entry,
                "--",
                "--socket-path",
                path,
            };
            const child_result = std.process.spawn(io, .{
                .argv = ui_argv,
                .cwd = .{ .path = runtime.cwd },
                .stdin = .inherit,
                .stdout = .inherit,
                .stderr = .inherit,
            });

            if (child_result) |child| {
                ui_child = child;
            } else |err| {
                try stderr_writer.print("Error: Failed to start UI ({s})\n", .{@errorName(err)});
                try stderr_writer.flush();
            }
        }
    }

    var socket_reader_buffer: [2048]u8 = undefined;
    var socket_writer_buffer: [2048]u8 = undefined;
    var socket_reader: std.Io.net.Stream.Reader = undefined;
    var socket_writer: std.Io.net.Stream.Writer = undefined;
    const tick_duration = Io.Clock.Duration{ .clock = .awake, .raw = Io.Duration.fromMilliseconds(200) };
    var timer_finished_notified = false;
    var eta_projection = EtaProjection{};

    if (socket_server) |*server| {
        // Step 9: Block until TUI connects, then send initial timer projection.
        var accepted = server.accept(io) catch |err| {
            try stderr_writer.print("Error: Failed to accept UI socket connection ({s})\n", .{@errorName(err)});
            try stderr_writer.flush();
            std.process.exit(1);
        };
        socket_reader = accepted.reader(io, &socket_reader_buffer);
        socket_writer = accepted.writer(io, &socket_writer_buffer);
        socket_stream = accepted;

        sendTimerProjection(
            allocator,
            io,
            &socket_writer.interface,
            &countdown_timer,
            total_duration_seconds,
            &timer_finished_notified,
            &eta_projection,
        ) catch |err| {
            try stderr_writer.print("Error: Failed to send initial socket timer event ({s})\n", .{@errorName(err)});
            try stderr_writer.flush();
            std.process.exit(1);
        };
    }

    var stdin_buffer: [1024]u8 = undefined;
    var stdin_reader: Io.File.Reader = .initStreaming(.stdin(), io, &stdin_buffer);

    // Step 10: Main loop
    // - poll input sources (stdin/socket)
    // - apply commands
    // - advance timer
    // - emit projection updates
    runEventLoop(
        allocator,
        io,
        stderr_writer,
        stdout_writer,
        stdin_is_tty,
        &stdin_reader.interface,
        &socket_reader.interface,
        &socket_writer.interface,
        &countdown_timer,
        total_duration_seconds,
        &timer_finished_notified,
        &eta_projection,
        &socket_stream,
        tick_duration,
    );

    // This code is unreachable as runEventLoop() exits via std.process.exit()
}

test "configErrorMessage - mapping" {
    try std.testing.expectEqualStrings(
        "Error: --minutes requires a numeric value\n",
        configErrorMessage(conf.ParseError.MissingMinutesValue),
    );
    try std.testing.expectEqualStrings(
        "Error: --seconds requires a numeric value\n",
        configErrorMessage(conf.ParseError.MissingSecondsValue),
    );
    try std.testing.expectEqualStrings(
        "Error: Unknown argument. Use --help for usage information\n",
        configErrorMessage(conf.ParseError.UnknownArgument),
    );
    try std.testing.expectEqualStrings(
        "Error: Invalid numeric value provided\n",
        configErrorMessage(conf.ParseError.InvalidNumber),
    );
    try std.testing.expectEqualStrings(
        "Error: Numeric value too large\n",
        configErrorMessage(conf.ParseError.Overflow),
    );
    try std.testing.expectEqualStrings(
        "Error: Out of memory\n",
        configErrorMessage(conf.ParseError.OutOfMemory),
    );
}

test "helpMessage - stable output" {
    try std.testing.expectEqualStrings(
        "Usage: tic [OPTIONS]\n\nOptions:\n  -m, --minutes <num>    Set countdown minutes\n  -s, --seconds <num>    Set countdown seconds\n      list               Select from history durations\n      list --delete      Delete history durations\n  -h, --help             Show this help message\n\nExample:\n  tic --minutes 25\n  tic -s 90\n  tic list\n  tic list --delete\n",
        helpMessage(),
    );
}

test "main/resolveEtaEpochSeconds - paused freezes eta" {
    var eta_projection = EtaProjection{};

    const running_eta = resolveEtaEpochSeconds(.running, 120, 1_000, &eta_projection);
    try std.testing.expectEqual(@as(u64, 1_120), running_eta);

    const paused_eta = resolveEtaEpochSeconds(.paused, 120, 2_000, &eta_projection);
    try std.testing.expectEqual(running_eta, paused_eta);
}

test "main/resolveEtaEpochSeconds - resume recalculates eta" {
    var eta_projection = EtaProjection{};

    _ = resolveEtaEpochSeconds(.running, 120, 1_000, &eta_projection);
    _ = resolveEtaEpochSeconds(.paused, 120, 2_000, &eta_projection);

    const resumed_eta = resolveEtaEpochSeconds(.running, 120, 2_100, &eta_projection);
    try std.testing.expectEqual(@as(u64, 2_220), resumed_eta);
}

test "main/gumBinaryFromEnv - uses override and ignores empty" {
    const allocator = std.testing.allocator;
    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();

    try std.testing.expectEqual(@as(?[]const u8, null), gumBinaryFromEnv(&environ_map));

    try environ_map.put(GUM_BINARY_ENV, "");
    try std.testing.expectEqual(@as(?[]const u8, null), gumBinaryFromEnv(&environ_map));

    try environ_map.put(GUM_BINARY_ENV, "/tmp/gum");
    const selected = gumBinaryFromEnv(&environ_map) orelse {
        try std.testing.expect(false);
        return;
    };
    try std.testing.expectEqualStrings("/tmp/gum", selected);
}

test "main/findAvailableGumBinary - prefers env override" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    const env_file = ".zig-test-gum-env-override";
    const candidate_file = ".zig-test-gum-candidate";
    Dir.cwd().deleteFile(io, env_file) catch {};
    Dir.cwd().deleteFile(io, candidate_file) catch {};
    defer Dir.cwd().deleteFile(io, env_file) catch {};
    defer Dir.cwd().deleteFile(io, candidate_file) catch {};

    var env_created = try Dir.cwd().createFile(io, env_file, .{});
    env_created.close(io);
    var candidate_created = try Dir.cwd().createFile(io, candidate_file, .{});
    candidate_created.close(io);

    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();
    try environ_map.put(GUM_BINARY_ENV, env_file);

    const resolved = findAvailableGumBinary(io, &environ_map, &[_][]const u8{candidate_file}) orelse {
        try std.testing.expect(false);
        return;
    };
    try std.testing.expectEqualStrings(env_file, resolved);
}

test "main/findAvailableGumBinary - falls back to bundled candidates" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    const candidate_file = ".zig-test-gum-candidate-only";
    Dir.cwd().deleteFile(io, candidate_file) catch {};
    defer Dir.cwd().deleteFile(io, candidate_file) catch {};

    var candidate_created = try Dir.cwd().createFile(io, candidate_file, .{});
    candidate_created.close(io);

    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();

    const resolved = findAvailableGumBinary(io, &environ_map, &[_][]const u8{candidate_file}) orelse {
        try std.testing.expect(false);
        return;
    };
    try std.testing.expectEqualStrings(candidate_file, resolved);
}

test "main/findAvailableGumBinary - returns null when unavailable" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();

    try std.testing.expectEqual(
        @as(?[]const u8, null),
        findAvailableGumBinary(io, &environ_map, &[_][]const u8{".zig-test-gum-not-found"}),
    );
}

test "main/resolveAppImageUiCwdCandidate - derives APPDIR runtime path" {
    const allocator = std.testing.allocator;
    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();

    try environ_map.put("APPDIR", "/tmp/tty-clock-timer-appdir");

    var buffer: [std.fs.max_path_bytes]u8 = undefined;
    const candidate = resolveAppImageUiCwdCandidate(&environ_map, &buffer) orelse {
        try std.testing.expect(false);
        return;
    };
    try std.testing.expectEqualStrings(
        "/tmp/tty-clock-timer-appdir/usr/lib/tty-clock-timer/tui",
        candidate,
    );
}

test "main/collectUiCwdCandidates - contract order is stable" {
    const allocator = std.testing.allocator;
    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();

    try environ_map.put("TTY_CLOCK_TUI_CWD", "/opt/tty-clock-timer/tui");
    try environ_map.put("APPDIR", "/tmp/tty-clock-timer-appdir");

    var buffer: [std.fs.max_path_bytes]u8 = undefined;
    const appdir_candidate = resolveAppImageUiCwdCandidate(&environ_map, &buffer);
    const candidates = collectUiCwdCandidates(&environ_map, appdir_candidate);
    const slice = candidates.asSlice();

    try std.testing.expectEqual(@as(usize, 5), slice.len);
    try std.testing.expectEqualStrings("/opt/tty-clock-timer/tui", slice[0]);
    try std.testing.expectEqualStrings("/tmp/tty-clock-timer-appdir/usr/lib/tty-clock-timer/tui", slice[1]);
    try std.testing.expectEqualStrings("tui", slice[2]);
    try std.testing.expectEqualStrings("../tui", slice[3]);
    try std.testing.expectEqualStrings("../../tui", slice[4]);
}

test "main/resolveUiEntry - uses default and override" {
    const allocator = std.testing.allocator;
    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();

    try std.testing.expectEqualStrings(DEFAULT_UI_ENTRY, resolveUiEntry(&environ_map));

    try environ_map.put("TTY_CLOCK_TUI_ENTRY", "dist/index.mjs");
    try std.testing.expectEqualStrings("dist/index.mjs", resolveUiEntry(&environ_map));
}

test "main/generateSocketPath - returns unique IPC socket paths" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    const first = try generateSocketPath(allocator, io);
    defer allocator.free(first);
    const second = try generateSocketPath(allocator, io);
    defer allocator.free(second);

    try std.testing.expect(!std.mem.eql(u8, first, second));
    try std.testing.expect(std.mem.startsWith(u8, first, "/tmp/tty-clock-timer-"));
    try std.testing.expect(std.mem.endsWith(u8, first, ".sock"));
}
