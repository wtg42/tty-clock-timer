//! CLI runtime orchestration for tty-clock-timer core.
//!
//! This module glues together argument parsing, history, sound setup, IPC, and timer updates.
//! It also coordinates the optional OpenTUI child process over a Unix socket bridge.

const std = @import("std");
const Io = std.Io;
const Dir = std.Io.Dir;
const conf = @import("lib/config.zig");
const history = @import("lib/history.zig");
const ipc = @import("lib/ipc.zig");
const timer_mod = @import("lib/timer.zig");

const SOCKET_BIND_RETRY_LIMIT: u8 = 8;
const MAX_UI_CWD_CANDIDATES: usize = 5;
const MAX_PROMPT_HELPER_CANDIDATES: usize = 6;
const DEFAULT_UI_ENTRY = "src/index.tsx";
const PROMPT_HELPER_ENTRY_ENV = "TTY_CLOCK_PROMPT_HELPER_ENTRY";
const SOCKET_FILE_FORMAT = "tty-clock-timer-{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}.sock";
const SOUND_PLAYER_CANDIDATES = [_][]const u8{ "afplay", "paplay", "pw-play", "aplay", "mpg123", "ffplay" };

const PromptSelection = union(enum) {
    chosen: u32,
    canceled,
    failed,
};

const PromptMultiSelection = union(enum) {
    chosen: [][]const u8,
    canceled,
    failed,
};

const PromptSoundSelection = union(enum) {
    chosen: conf.SoundConfig,
    canceled,
    failed,
};

const UiRuntimeContract = struct {
    cwd: []const u8,
    entry: []const u8,
};

const PromptHelperCandidates = struct {
    items: [MAX_PROMPT_HELPER_CANDIDATES][]const u8 = undefined,
    len: usize = 0,

    fn append(self: *PromptHelperCandidates, candidate: []const u8) void {
        if (candidate.len == 0) return;
        if (self.len >= self.items.len) return;
        self.items[self.len] = candidate;
        self.len += 1;
    }

    fn asSlice(self: *const PromptHelperCandidates) []const []const u8 {
        return self.items[0..self.len];
    }
};

const UiCwdCandidates = struct {
    items: [MAX_UI_CWD_CANDIDATES][]const u8 = undefined,
    len: usize = 0,

    /// Adds a UI cwd candidate when the value is non-empty and capacity allows it.
    fn append(self: *UiCwdCandidates, candidate: []const u8) void {
        if (candidate.len == 0) return;
        if (self.len >= self.items.len) return;
        self.items[self.len] = candidate;
        self.len += 1;
    }

    /// Returns the currently collected UI cwd candidates as a compact slice.
    fn asSlice(self: *const UiCwdCandidates) []const []const u8 {
        return self.items[0..self.len];
    }
};

/// Returns the CLI help text shown for onboarding and usage reminders.
fn helpMessage() []const u8 {
    return "Usage: ttc [OPTIONS]\n" ++
        "\n" ++
        "Options:\n" ++
        "  -m, --minutes <num>    Set countdown minutes\n" ++
        "  -s, --seconds <num>    Set countdown seconds\n" ++
        "      --setup-sound      Configure sound player + file\n" ++
        "      list               Select from history durations\n" ++
        "      list --delete      Delete history durations\n" ++
        "  -h, --help             Show this help message\n" ++
        "\n" ++
        "Example:\n" ++
        "  ttc --minutes 25\n" ++
        "  ttc -s 90\n" ++
        "  ttc --setup-sound\n" ++
        "  ttc list\n" ++
        "  ttc list --delete\n";
}

/// Maps internal timer state to the status string used by IPC payloads.
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

/// Reads current real clock seconds and clamps negative values to zero.
fn currentRealEpochSeconds(io: Io) u64 {
    const now_seconds = Io.Clock.real.now(io).toSeconds();
    return if (now_seconds < 0) 0 else @intCast(now_seconds);
}

/// Freezes a fresh ETA baseline for a new run, resume, or reset cycle.
fn freezeEtaForNewCycle(
    remaining_seconds: u32,
    now_epoch_seconds: u64,
    eta_projection: *EtaProjection,
) void {
    const base_seconds = now_epoch_seconds;
    const computed = std.math.add(u64, base_seconds, remaining_seconds) catch std.math.maxInt(u64);
    eta_projection.frozen_epoch_seconds = computed;
}

/// Resolves the ETA epoch, keeping it frozen while running or paused.
fn resolveEtaEpochSeconds(
    state: timer_mod.TimerState,
    remaining_seconds: u32,
    now_epoch_seconds: u64,
    eta_projection: *EtaProjection,
) u64 {
    // When running, return frozen ETA without recalculation
    if (state == .running) {
        return eta_projection.frozen_epoch_seconds orelse {
            // Fallback: compute if no frozen value exists (should not happen in normal flow)
            const base_seconds = now_epoch_seconds;
            const computed = std.math.add(u64, base_seconds, remaining_seconds) catch std.math.maxInt(u64);
            return computed;
        };
    }

    // When paused, maintain frozen ETA
    if (state == .paused) {
        if (eta_projection.frozen_epoch_seconds) |frozen| return frozen;
        // Fallback: compute if no frozen value exists (should not happen in normal flow)
        const base_seconds = now_epoch_seconds;
        const computed = std.math.add(u64, base_seconds, remaining_seconds) catch std.math.maxInt(u64);
        return computed;
    }

    // For other states (idle, finished), compute fresh ETA
    const base_seconds = now_epoch_seconds;
    const computed = std.math.add(u64, base_seconds, remaining_seconds) catch std.math.maxInt(u64);
    return computed;
}

/// Converts CLI parse errors into readable messages for terminal output.
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

/// Builds a friendly duration label like `MM:SS (Ns)` for menus.
fn formatDurationLabel(allocator: std.mem.Allocator, duration_seconds: u32) ![]u8 {
    const minutes = duration_seconds / 60;
    const seconds = duration_seconds % 60;
    return std.fmt.allocPrint(allocator, "{d:0>2}:{d:0>2} ({d}s)", .{ minutes, seconds, duration_seconds });
}

/// Checks whether a file path is accessible from the current working directory.
fn pathExists(io: Io, path: []const u8) bool {
    const file = Dir.cwd().openFile(io, path, .{}) catch return false;
    file.close(io);
    return true;
}

/// Reads prompt helper override from environment and ignores empty values.
fn promptHelperEntryFromEnv(environ_map: *const std.process.Environ.Map) ?[]const u8 {
    const value = environ_map.get(PROMPT_HELPER_ENTRY_ENV) orelse return null;
    if (value.len == 0) return null;
    return value;
}

/// Builds an AppImage prompt helper candidate from `APPDIR`.
fn resolveAppImagePromptHelperCandidate(
    environ_map: *const std.process.Environ.Map,
    buffer: []u8,
) ?[]const u8 {
    const appdir = environ_map.get("APPDIR") orelse return null;
    if (appdir.len == 0) return null;
    return std.fmt.bufPrint(buffer, "{s}/usr/lib/tty-clock-timer/tui/prompts/helper.js", .{appdir}) catch null;
}

fn resolveUiCwdPromptHelperCandidate(
    environ_map: *const std.process.Environ.Map,
    buffer: []u8,
) ?[]const u8 {
    const ui_cwd = environ_map.get("TTY_CLOCK_TUI_CWD") orelse return null;
    if (ui_cwd.len == 0) return null;
    return std.fmt.bufPrint(buffer, "{s}/prompts/helper.js", .{ui_cwd}) catch null;
}

/// Collects ordered prompt helper entry candidates from env overrides and fallbacks.
fn collectPromptHelperCandidates(
    environ_map: *const std.process.Environ.Map,
    ui_cwd_candidate: ?[]const u8,
    appdir_candidate: ?[]const u8,
) PromptHelperCandidates {
    var candidates = PromptHelperCandidates{};
    if (promptHelperEntryFromEnv(environ_map)) |override| {
        candidates.append(override);
    }
    if (ui_cwd_candidate) |candidate| {
        candidates.append(candidate);
    }
    if (appdir_candidate) |candidate| {
        candidates.append(candidate);
    }
    const local_fallbacks = [_][]const u8{
        "tui/dist/prompts/helper.js",
        "../tui/dist/prompts/helper.js",
        "../../tui/dist/prompts/helper.js",
    };
    for (local_fallbacks) |fallback| {
        candidates.append(fallback);
    }
    return candidates;
}

/// Picks the first usable prompt helper entry from env override or bundled candidates.
fn findAvailablePromptHelperEntry(
    io: Io,
    environ_map: *const std.process.Environ.Map,
    candidates: []const []const u8,
) ?[]const u8 {
    if (promptHelperEntryFromEnv(environ_map)) |env_path| {
        if (pathExists(io, env_path)) return env_path;
    }

    for (candidates) |candidate| {
        if (pathExists(io, candidate)) return candidate;
    }

    return null;
}

/// Finds a prompt helper entry using configured search candidates.
fn findPromptHelperEntry(io: Io, environ_map: *const std.process.Environ.Map) ?[]const u8 {
    var ui_cwd_candidate_buffer: [std.fs.max_path_bytes]u8 = undefined;
    var appdir_candidate_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const ui_cwd_candidate = resolveUiCwdPromptHelperCandidate(environ_map, &ui_cwd_candidate_buffer);
    const appdir_candidate = resolveAppImagePromptHelperCandidate(environ_map, &appdir_candidate_buffer);
    const candidates = collectPromptHelperCandidates(environ_map, ui_cwd_candidate, appdir_candidate);
    return findAvailablePromptHelperEntry(io, environ_map, candidates.asSlice());
}

/// Duplicates an argument, tracks ownership, and appends it to argv.
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

const PromptCommand = enum {
    history_select,
    history_delete,
    setup_sound,

    fn subcommand(self: PromptCommand) []const u8 {
        return switch (self) {
            .history_select => "history-select",
            .history_delete => "history-delete",
            .setup_sound => "setup-sound",
        };
    }
};

const PromptCommandResult = struct {
    stdout: []u8,
    term: std.process.Child.Term,
};

fn runPromptHelperCommand(
    allocator: std.mem.Allocator,
    io: Io,
    environ_map: *const std.process.Environ.Map,
    command: PromptCommand,
    extra_args: []const []const u8,
) !PromptCommandResult {
    if (!std.process.can_spawn) return error.PromptHelperUnavailable;

    var argv_owned: std.ArrayList([]u8) = .empty;
    defer {
        for (argv_owned.items) |value| allocator.free(value);
        argv_owned.deinit(allocator);
    }

    var argv_list: std.ArrayList([]const u8) = .empty;
    defer argv_list.deinit(allocator);

    const helper_entry = findPromptHelperEntry(io, environ_map) orelse return error.PromptHelperUnavailable;
    try appendArgOwned(allocator, &argv_list, &argv_owned, "bun");
    try appendArgOwned(allocator, &argv_list, &argv_owned, "run");
    try appendArgOwned(allocator, &argv_list, &argv_owned, helper_entry);
    try appendArgOwned(allocator, &argv_list, &argv_owned, "--");
    try appendArgOwned(allocator, &argv_list, &argv_owned, command.subcommand());
    for (extra_args) |arg| try appendArgOwned(allocator, &argv_list, &argv_owned, arg);

    var child = std.process.spawn(io, .{
        .argv = argv_list.items,
        .stdin = .inherit,
        .stdout = .pipe,
        .stderr = .inherit,
    }) catch return error.PromptHelperSpawnFailed;
    defer child.kill(io);

    var helper_stdout_buffer: [4096]u8 = undefined;
    var helper_stdout_reader = child.stdout.?.readerStreaming(io, &helper_stdout_buffer);
    const helper_stdout = helper_stdout_reader.interface.allocRemaining(allocator, .limited(16384)) catch return error.PromptHelperReadFailed;

    const term = child.wait(io) catch {
        allocator.free(helper_stdout);
        return error.PromptHelperWaitFailed;
    };

    return .{ .stdout = helper_stdout, .term = term };
}

fn chooseWithPromptHelper(
    allocator: std.mem.Allocator,
    io: Io,
    environ_map: *const std.process.Environ.Map,
    entries: []const history.Entry,
) !PromptSelection {
    var extra_args: std.ArrayList([]const u8) = .empty;
    defer extra_args.deinit(allocator);
    var owned_values: std.ArrayList([]u8) = .empty;
    defer {
        for (owned_values.items) |value| allocator.free(value);
        owned_values.deinit(allocator);
    }

    for (entries) |entry| {
        const value = try std.fmt.allocPrint(allocator, "{d}", .{entry.duration_seconds});
        try owned_values.append(allocator, value);
        try extra_args.append(allocator, "--duration-seconds");
        try extra_args.append(allocator, value);
    }

    const command_result = runPromptHelperCommand(allocator, io, environ_map, .history_select, extra_args.items) catch return .failed;
    defer allocator.free(command_result.stdout);

    var parsed = std.json.parseFromSlice(std.json.Value, allocator, command_result.stdout, .{}) catch return .failed;
    defer parsed.deinit();
    if (parsed.value != .object) return .failed;

    const status = parsed.value.object.get("status") orelse return .failed;
    if (status != .string) return .failed;
    if (std.mem.eql(u8, status.string, "canceled")) return .canceled;
    if (!std.mem.eql(u8, status.string, "submitted")) return .failed;

    const duration_value = parsed.value.object.get("duration_seconds") orelse return .failed;
    const duration_int = switch (duration_value) {
        .integer => |value| value,
        else => return .failed,
    };
    if (duration_int <= 0 or duration_int > std.math.maxInt(u32)) return .failed;
    return .{ .chosen = @intCast(duration_int) };
}

fn deleteWithPromptHelper(
    allocator: std.mem.Allocator,
    io: Io,
    environ_map: *const std.process.Environ.Map,
    entries: []const history.Entry,
) !PromptMultiSelection {
    var extra_args: std.ArrayList([]const u8) = .empty;
    defer extra_args.deinit(allocator);
    var owned_values: std.ArrayList([]u8) = .empty;
    defer {
        for (owned_values.items) |value| allocator.free(value);
        owned_values.deinit(allocator);
    }

    for (entries) |entry| {
        const value = try std.fmt.allocPrint(allocator, "{d}", .{entry.duration_seconds});
        try owned_values.append(allocator, value);
        try extra_args.append(allocator, "--duration-seconds");
        try extra_args.append(allocator, value);
    }

    const command_result = runPromptHelperCommand(allocator, io, environ_map, .history_delete, extra_args.items) catch return .failed;
    defer allocator.free(command_result.stdout);

    var parsed = std.json.parseFromSlice(std.json.Value, allocator, command_result.stdout, .{}) catch return .failed;
    defer parsed.deinit();
    if (parsed.value != .object) return .failed;

    const status = parsed.value.object.get("status") orelse return .failed;
    if (status != .string) return .failed;
    if (std.mem.eql(u8, status.string, "canceled")) return .canceled;
    if (!std.mem.eql(u8, status.string, "submitted")) return .failed;

    const selected_labels = parsed.value.object.get("selected_labels") orelse return .failed;
    if (selected_labels != .array) return .failed;

    var labels: std.ArrayList([]const u8) = .empty;
    defer labels.deinit(allocator);
    for (selected_labels.array.items) |item| {
        if (item != .string) return .failed;
        try labels.append(allocator, try allocator.dupe(u8, item.string));
    }
    if (labels.items.len == 0) return .canceled;
    return .{ .chosen = try labels.toOwnedSlice(allocator) };
}

fn runSetupSoundPrompt(
    allocator: std.mem.Allocator,
    io: Io,
    environ_map: *const std.process.Environ.Map,
    detected_players: []const []const u8,
) !PromptSoundSelection {
    var extra_args: std.ArrayList([]const u8) = .empty;
    defer extra_args.deinit(allocator);

    for (detected_players) |player| {
        try extra_args.append(allocator, "--player");
        try extra_args.append(allocator, player);
    }

    const command_result = runPromptHelperCommand(allocator, io, environ_map, .setup_sound, extra_args.items) catch return .failed;
    defer allocator.free(command_result.stdout);

    var parsed = std.json.parseFromSlice(std.json.Value, allocator, command_result.stdout, .{}) catch return .failed;
    defer parsed.deinit();
    if (parsed.value != .object) return .failed;

    const status = parsed.value.object.get("status") orelse return .failed;
    if (status != .string) return .failed;
    if (std.mem.eql(u8, status.string, "canceled")) return .canceled;
    if (!std.mem.eql(u8, status.string, "submitted")) return .failed;

    const player_value = parsed.value.object.get("player") orelse return .failed;
    const file_value = parsed.value.object.get("file") orelse return .failed;
    if (player_value != .string or file_value != .string) return .failed;

    return .{ .chosen = .{
        .player = try allocator.dupe(u8, player_value.string),
        .file = try allocator.dupe(u8, file_value.string),
    } };
}

/// Resolves a sound player binary path by invoking `which`.
fn detectPlayerPath(
    allocator: std.mem.Allocator,
    io: Io,
    name: []const u8,
) !?[]u8 {
    if (!std.process.can_spawn) return null;

    const argv = &[_][]const u8{ "which", name };
    var child = std.process.spawn(io, .{
        .argv = argv,
        .stdin = .ignore,
        .stdout = .pipe,
        .stderr = .ignore,
    }) catch {
        return null;
    };
    defer child.kill(io);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_reader = child.stdout.?.readerStreaming(io, &stdout_buffer);
    const output = stdout_reader.interface.allocRemaining(allocator, .limited(4096)) catch {
        return null;
    };
    defer allocator.free(output);

    const term = child.wait(io) catch return null;
    switch (term) {
        .exited => |code| if (code != 0) return null,
        else => return null,
    }

    const path = std.mem.trim(u8, output, " \t\r\n");
    if (path.len == 0) return null;
    var line_iter = std.mem.splitScalar(u8, path, '\n');
    const first_line = line_iter.first();
    return try allocator.dupe(u8, first_line);
}

/// Guides interactive sound setup and persists the chosen player and file.
fn runSetupSound(
    allocator: std.mem.Allocator,
    io: Io,
    stdout_writer: *Io.Writer,
    environ_map: *const std.process.Environ.Map,
) !void {
    var detected_players: std.ArrayList([]const u8) = .empty;
    defer {
        for (detected_players.items) |player| allocator.free(player);
        detected_players.deinit(allocator);
    }

    for (SOUND_PLAYER_CANDIDATES) |candidate| {
        const maybe_path = try detectPlayerPath(allocator, io, candidate);
        if (maybe_path) |path| {
            try detected_players.append(allocator, path);
        }
    }

    const prompt_result = try runSetupSoundPrompt(
        allocator,
        io,
        environ_map,
        detected_players.items,
    );

    const selected_sound = switch (prompt_result) {
        .chosen => |value| value,
        .canceled => return error.UserCanceled,
        .failed => return error.PromptHelperFailed,
    };
    defer {
        allocator.free(selected_sound.player);
        allocator.free(selected_sound.file);
    }

    try conf.writeConfig(allocator, io, environ_map, .{
        .sound = selected_sound,
    });

    try stdout_writer.print("Sound setup saved.\n", .{});
    try stdout_writer.flush();
}

/// Loads history and resolves one duration via prompt helper.
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

    switch (try chooseWithPromptHelper(allocator, io, environ_map, entries)) {
        .chosen => |selected| return selected,
        .canceled => return null,
        .failed => {
            try stderr_writer.print("Error: prompt helper selection failed\n", .{});
            try stderr_writer.flush();
            return null;
        },
    }
}

/// Loads history, deletes selected entries, and writes the updated list.
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

    switch (try deleteWithPromptHelper(allocator, io, environ_map, entries)) {
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
            try stderr_writer.print("Error: prompt helper selection failed\n", .{});
            try stderr_writer.flush();
        },
    }

    try stdout_writer.flush();
}

/// Consumes buffered stdin commands and reports whether quit was requested.
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

/// Emits the current timer projection to stdout or socket writer.
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

    try ipc.updateTimer(
        allocator,
        writer,
        remaining_seconds,
        total_duration_seconds,
        timerStateToStatus(timer.state),
        eta_epoch_seconds,
    );
    try writer.flush();
}

/// Deletes a stale socket file and treats missing path as harmless.
fn clearSocketPath(io: Io, path: []const u8) !void {
    Dir.cwd().deleteFile(io, path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
}

/// Applies one IPC command, sends command result, and returns exit intent.
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
                // Freeze ETA for the resumed cycle
                const remaining_seconds = @as(u32, @intCast(timer.remaining_ns / std.time.ns_per_s));
                freezeEtaForNewCycle(remaining_seconds, currentRealEpochSeconds(io), eta_projection);
            }
        },
        .reset => {
            timer.reset();
            try timer.start(io);
            timer_finished_notified.* = false;
            // Freeze ETA for the new cycle
            const remaining_seconds = @as(u32, @intCast(timer.remaining_ns / std.time.ns_per_s));
            freezeEtaForNewCycle(remaining_seconds, currentRealEpochSeconds(io), eta_projection);
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

/// Parses buffered socket messages and executes command payloads.
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

/// Configures stdin raw mode for single-key control and returns restore context.
fn setupRawMode(io: Io, stderr_writer: *Io.Writer) !RawModeContext {
    var original_termios: ?std.posix.termios = null;
    const stdin_handle = Io.File.stdin().handle;
    if (!(Io.File.stdin().isTty(io) catch false)) {
        return .{
            .original_termios = null,
            .stdin_is_tty = false,
        };
    }
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

/// Builds an AppImage TUI runtime cwd candidate from `APPDIR`.
fn resolveAppImageUiCwdCandidate(
    environ_map: *const std.process.Environ.Map,
    buffer: []u8,
) ?[]const u8 {
    const appdir = environ_map.get("APPDIR") orelse return null;
    if (appdir.len == 0) return null;
    return std.fmt.bufPrint(buffer, "{s}/usr/lib/tty-clock-timer/tui", .{appdir}) catch null;
}

/// Collects ordered TUI cwd candidates from env overrides and fallbacks.
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

/// Finds the first existing TUI working directory from candidate paths.
fn findUiCwd(io: Io, candidates: []const []const u8) ?[]const u8 {
    for (candidates) |candidate| {
        if (Dir.cwd().openDir(io, candidate, .{})) |dir| {
            dir.close(io);
            return candidate;
        } else |_| {}
    }
    return null;
}

/// Resolves the TUI entry file path from env override or default value.
fn resolveUiEntry(environ_map: *const std.process.Environ.Map) []const u8 {
    return environ_map.get("TTY_CLOCK_TUI_ENTRY") orelse DEFAULT_UI_ENTRY;
}

/// Checks whether the configured TUI entry exists under the resolved cwd.
fn uiEntryExists(io: Io, cwd: []const u8, entry: []const u8) bool {
    var dir = Dir.cwd().openDir(io, cwd, .{}) catch return false;
    defer dir.close(io);

    const file = dir.openFile(io, entry, .{}) catch return false;
    file.close(io);
    return true;
}

/// Prints diagnostics when no valid TUI runtime cwd can be resolved.
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

/// Prints diagnostics when configured TUI entry path is invalid.
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

/// Gives UI child a short grace period, then waits or force-kills.
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

const SocketTempDirCandidates = struct {
    items: [2][]const u8 = undefined,
    len: usize = 0,

    fn append(self: *SocketTempDirCandidates, candidate: []const u8) void {
        if (candidate.len == 0) return;
        for (self.items[0..self.len]) |existing| {
            if (std.mem.eql(u8, existing, candidate)) return;
        }
        self.items[self.len] = candidate;
        self.len += 1;
    }

    fn asSlice(self: *const SocketTempDirCandidates) []const []const u8 {
        return self.items[0..self.len];
    }
};

fn collectSocketTempDirCandidates(environ_map: *const std.process.Environ.Map) SocketTempDirCandidates {
    var candidates = SocketTempDirCandidates{};
    if (environ_map.get("TMPDIR")) |tmpdir| candidates.append(tmpdir);
    candidates.append("/tmp");
    return candidates;
}

/// Generates a random per-run Unix socket path below one temp directory.
fn generateSocketPathInDir(allocator: std.mem.Allocator, io: Io, temp_dir: []const u8) ![]u8 {
    var random_bytes: [8]u8 = undefined;
    io.random(&random_bytes);
    const file_name = try std.fmt.allocPrint(
        allocator,
        SOCKET_FILE_FORMAT,
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
    defer allocator.free(file_name);
    return std.fs.path.join(allocator, &.{ temp_dir, file_name });
}

/// Selects the first temp directory that yields a valid Unix socket address.
fn generateSocketPath(
    allocator: std.mem.Allocator,
    io: Io,
    environ_map: *const std.process.Environ.Map,
) ![]u8 {
    const candidates = collectSocketTempDirCandidates(environ_map);
    for (candidates.asSlice()) |temp_dir| {
        const path = try generateSocketPathInDir(allocator, io, temp_dir);
        if (std.Io.net.UnixAddress.init(path)) |_| {
            return path;
        } else |_| {
            allocator.free(path);
        }
    }
    return error.NameTooLong;
}

/// Creates and binds the Unix socket server with retry handling.
fn setupSocket(
    allocator: std.mem.Allocator,
    io: Io,
    stderr_writer: *Io.Writer,
    environ_map: *const std.process.Environ.Map,
) !SocketServerContext {
    const candidates = collectSocketTempDirCandidates(environ_map);
    for (candidates.asSlice()) |temp_dir| {
        var attempts: u8 = 0;
        while (attempts < SOCKET_BIND_RETRY_LIMIT) : (attempts += 1) {
            const socket_path = try generateSocketPathInDir(allocator, io, temp_dir);

            const socket_address = std.Io.net.UnixAddress.init(socket_path) catch {
                allocator.free(socket_path);
                break;
            };

            clearSocketPath(io, socket_path) catch {
                allocator.free(socket_path);
                break;
            };

            const server = std.Io.net.UnixAddress.listen(&socket_address, io, .{}) catch |err| switch (err) {
                error.AddressInUse => {
                    clearSocketPath(io, socket_path) catch {};
                    allocator.free(socket_path);
                    continue;
                },
                else => {
                    allocator.free(socket_path);
                    break;
                },
            };

            return SocketServerContext{
                .server = server,
                .socket_path = socket_path,
            };
        }
    }

    try stderr_writer.print(
        "Error: Failed to bind a Unix socket in TMPDIR or /tmp\n",
        .{},
    );
    try stderr_writer.flush();
    std.process.exit(1);
}

/// Runs the main polling loop for stdin/socket input, commands, and timer ticks.
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

/// Runs the CLI lifecycle from argument parsing to timer loop shutdown.
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

    if (config.command == .setup_sound) {
        runSetupSound(
            allocator,
            io,
            stdout_writer,
            init.environ_map,
        ) catch |err| switch (err) {
            error.UserCanceled => {
                try stderr_writer.print("Sound setup canceled.\n", .{});
                try stderr_writer.flush();
                std.process.exit(1);
            },
            error.PromptHelperFailed => {
                try stderr_writer.print("Error: prompt helper interaction failed\n", .{});
                try stderr_writer.flush();
                std.process.exit(1);
            },
            else => {
                try stderr_writer.print("Error: Failed to setup sound ({s})\n", .{@errorName(err)});
                try stderr_writer.flush();
                std.process.exit(1);
            },
        };
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
        .setup_sound => unreachable,
    };

    const user_config = conf.readConfig(allocator, io, init.environ_map) catch conf.UserConfig{};
    defer conf.freeUserConfig(allocator, user_config);
    const total_duration_ns = @as(u64, total_duration_seconds) * std.time.ns_per_s;

    // Step 4: Configure stdin into raw mode for timer runtime.
    // This lets us react to single-key input (`q`) without waiting for Enter.
    const raw_mode = try setupRawMode(io, stderr_writer);
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
        const server_ctx = try setupSocket(allocator, io, stderr_writer, init.environ_map);
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

    // Freeze initial ETA for the started cycle
    {
        const remaining_seconds = @as(u32, @intCast(countdown_timer.remaining_ns / std.time.ns_per_s));
        freezeEtaForNewCycle(remaining_seconds, currentRealEpochSeconds(io), &eta_projection);
    }

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

        const init_sound: ?ipc.SoundConfig = if (user_config.sound) |sound| .{
            .player = sound.player,
            .file = sound.file,
        } else null;

        ipc.sendInit(
            allocator,
            &socket_writer.interface,
            init_sound,
        ) catch |err| {
            try stderr_writer.print("Error: Failed to send init event ({s})\n", .{@errorName(err)});
            try stderr_writer.flush();
            std.process.exit(1);
        };
        socket_writer.interface.flush() catch |err| {
            try stderr_writer.print("Error: Failed to flush init event ({s})\n", .{@errorName(err)});
            try stderr_writer.flush();
            std.process.exit(1);
        };

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
        "Usage: ttc [OPTIONS]\n\nOptions:\n  -m, --minutes <num>    Set countdown minutes\n  -s, --seconds <num>    Set countdown seconds\n      --setup-sound      Configure sound player + file\n      list               Select from history durations\n      list --delete      Delete history durations\n  -h, --help             Show this help message\n\nExample:\n  ttc --minutes 25\n  ttc -s 90\n  ttc --setup-sound\n  ttc list\n  ttc list --delete\n",
        helpMessage(),
    );
}

test "main/resolveEtaEpochSeconds - running freezes eta" {
    var eta_projection = EtaProjection{};

    // Freeze ETA for the running cycle
    freezeEtaForNewCycle(120, 1_000, &eta_projection);
    const running_eta = resolveEtaEpochSeconds(.running, 120, 1_000, &eta_projection);
    try std.testing.expectEqual(@as(u64, 1_120), running_eta);

    // Even with different time, running state returns frozen ETA
    const frozen_eta = resolveEtaEpochSeconds(.running, 120, 1_500, &eta_projection);
    try std.testing.expectEqual(@as(u64, 1_120), frozen_eta);
}

test "main/resolveEtaEpochSeconds - paused freezes eta" {
    var eta_projection = EtaProjection{};

    // Freeze ETA for running cycle, then pause
    freezeEtaForNewCycle(120, 1_000, &eta_projection);
    const running_eta = resolveEtaEpochSeconds(.running, 120, 1_000, &eta_projection);
    try std.testing.expectEqual(@as(u64, 1_120), running_eta);

    const paused_eta = resolveEtaEpochSeconds(.paused, 120, 2_000, &eta_projection);
    try std.testing.expectEqual(running_eta, paused_eta);
}

test "main/resolveEtaEpochSeconds - resume recalculates eta" {
    var eta_projection = EtaProjection{};

    // Initial running cycle
    freezeEtaForNewCycle(120, 1_000, &eta_projection);
    _ = resolveEtaEpochSeconds(.running, 120, 1_000, &eta_projection);

    // Pause (maintains frozen ETA)
    _ = resolveEtaEpochSeconds(.paused, 120, 2_000, &eta_projection);

    // Freeze new ETA for resumed cycle
    freezeEtaForNewCycle(120, 2_100, &eta_projection);
    const resumed_eta = resolveEtaEpochSeconds(.running, 120, 2_100, &eta_projection);
    try std.testing.expectEqual(@as(u64, 2_220), resumed_eta);
}

test "main/resolveEtaEpochSeconds - minute boundary no drift" {
    var eta_projection = EtaProjection{};

    // Simulate scenario: current time is 10:59:50 (epoch 39590)
    // remaining is 20 seconds, so ETA should be 11:00:10 (epoch 39610)
    const base_time: u64 = 39590;
    const remaining: u32 = 20;

    freezeEtaForNewCycle(remaining, base_time, &eta_projection);
    const eta1 = resolveEtaEpochSeconds(.running, remaining, base_time, &eta_projection);
    try std.testing.expectEqual(@as(u64, 39610), eta1);

    // Simulate multiple reads during the same minute (even if real time advances)
    // ETA should remain frozen, no minute drift
    const eta2 = resolveEtaEpochSeconds(.running, remaining, base_time + 5, &eta_projection);
    try std.testing.expectEqual(@as(u64, 39610), eta2);

    const eta3 = resolveEtaEpochSeconds(.running, remaining, base_time + 10, &eta_projection);
    try std.testing.expectEqual(@as(u64, 39610), eta3);

    // When resume happens at later time, recalculate with new base
    freezeEtaForNewCycle(20, base_time + 10, &eta_projection);
    const resumed_eta = resolveEtaEpochSeconds(.running, 20, base_time + 10, &eta_projection);
    try std.testing.expectEqual(@as(u64, base_time + 30), resumed_eta);
}

test "main/promptHelperEntryFromEnv - uses override and ignores empty" {
    const allocator = std.testing.allocator;
    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();

    try std.testing.expectEqual(@as(?[]const u8, null), promptHelperEntryFromEnv(&environ_map));

    try environ_map.put(PROMPT_HELPER_ENTRY_ENV, "");
    try std.testing.expectEqual(@as(?[]const u8, null), promptHelperEntryFromEnv(&environ_map));

    try environ_map.put(PROMPT_HELPER_ENTRY_ENV, "/tmp/helper.js");
    const selected = promptHelperEntryFromEnv(&environ_map) orelse {
        try std.testing.expect(false);
        return;
    };
    try std.testing.expectEqualStrings("/tmp/helper.js", selected);
}

test "main/findAvailablePromptHelperEntry - prefers env override" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    const env_file = ".zig-test-helper-env-override.js";
    const candidate_file = ".zig-test-helper-candidate.js";
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
    try environ_map.put(PROMPT_HELPER_ENTRY_ENV, env_file);

    const resolved = findAvailablePromptHelperEntry(io, &environ_map, &[_][]const u8{candidate_file}) orelse {
        try std.testing.expect(false);
        return;
    };
    try std.testing.expectEqualStrings(env_file, resolved);
}

test "main/findAvailablePromptHelperEntry - falls back to bundled candidates" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    const candidate_file = ".zig-test-helper-candidate-only.js";
    Dir.cwd().deleteFile(io, candidate_file) catch {};
    defer Dir.cwd().deleteFile(io, candidate_file) catch {};

    var candidate_created = try Dir.cwd().createFile(io, candidate_file, .{});
    candidate_created.close(io);

    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();

    const resolved = findAvailablePromptHelperEntry(io, &environ_map, &[_][]const u8{candidate_file}) orelse {
        try std.testing.expect(false);
        return;
    };
    try std.testing.expectEqualStrings(candidate_file, resolved);
}

test "main/findAvailablePromptHelperEntry - returns null when unavailable" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();

    try std.testing.expectEqual(
        @as(?[]const u8, null),
        findAvailablePromptHelperEntry(io, &environ_map, &[_][]const u8{".zig-test-helper-not-found.js"}),
    );
}

test "main/resolveAppImagePromptHelperCandidate - derives APPDIR helper path" {
    const allocator = std.testing.allocator;
    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();

    try environ_map.put("APPDIR", "/tmp/tty-clock-timer-appdir");

    var buffer: [std.fs.max_path_bytes]u8 = undefined;
    const candidate = resolveAppImagePromptHelperCandidate(&environ_map, &buffer) orelse {
        try std.testing.expect(false);
        return;
    };
    try std.testing.expectEqualStrings(
        "/tmp/tty-clock-timer-appdir/usr/lib/tty-clock-timer/tui/prompts/helper.js",
        candidate,
    );
}

test "main/collectPromptHelperCandidates - contract order is stable" {
    const allocator = std.testing.allocator;
    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();

    try environ_map.put(PROMPT_HELPER_ENTRY_ENV, "/opt/tty-clock-timer/tui/prompts/helper.js");
    try environ_map.put("TTY_CLOCK_TUI_CWD", "/workspace/tui-runtime");
    try environ_map.put("APPDIR", "/tmp/tty-clock-timer-appdir");

    var ui_buffer: [std.fs.max_path_bytes]u8 = undefined;
    var buffer: [std.fs.max_path_bytes]u8 = undefined;
    const ui_cwd_candidate = resolveUiCwdPromptHelperCandidate(&environ_map, &ui_buffer);
    const appdir_candidate = resolveAppImagePromptHelperCandidate(&environ_map, &buffer);
    const candidates = collectPromptHelperCandidates(&environ_map, ui_cwd_candidate, appdir_candidate);
    const slice = candidates.asSlice();

    try std.testing.expectEqual(@as(usize, 6), slice.len);
    try std.testing.expectEqualStrings("/opt/tty-clock-timer/tui/prompts/helper.js", slice[0]);
    try std.testing.expectEqualStrings("/workspace/tui-runtime/prompts/helper.js", slice[1]);
    try std.testing.expectEqualStrings("/tmp/tty-clock-timer-appdir/usr/lib/tty-clock-timer/tui/prompts/helper.js", slice[2]);
    try std.testing.expectEqualStrings("tui/dist/prompts/helper.js", slice[3]);
    try std.testing.expectEqualStrings("../tui/dist/prompts/helper.js", slice[4]);
    try std.testing.expectEqualStrings("../../tui/dist/prompts/helper.js", slice[5]);
}

test "main/chooseWithPromptHelper - parses submitted duration" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    const helper_file = ".zig-test-prompt-helper-select.js";
    defer Dir.cwd().deleteFile(io, helper_file) catch {};
    try Dir.cwd().writeFile(io, .{
        .sub_path = helper_file,
        .data = "process.stdout.write('{\"status\":\"submitted\",\"duration_seconds\":90}\\n');\n",
    });

    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();
    try environ_map.put(PROMPT_HELPER_ENTRY_ENV, helper_file);

    const entries = [_]history.Entry{
        .{ .duration_seconds = 60, .last_used_at = 0 },
        .{ .duration_seconds = 90, .last_used_at = 0 },
    };

    const result = try chooseWithPromptHelper(allocator, io, &environ_map, entries[0..]);
    switch (result) {
        .chosen => |value| try std.testing.expectEqual(@as(u32, 90), value),
        else => try std.testing.expect(false),
    }
}

test "main/chooseWithPromptHelper - maps helper error to failed" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    const helper_file = ".zig-test-prompt-helper-error.js";
    defer Dir.cwd().deleteFile(io, helper_file) catch {};
    try Dir.cwd().writeFile(io, .{
        .sub_path = helper_file,
        .data = "process.stdout.write('{\"status\":\"error\",\"code\":\"bad\"}\\n');\nprocess.exit(1);\n",
    });

    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();
    try environ_map.put(PROMPT_HELPER_ENTRY_ENV, helper_file);

    const entries = [_]history.Entry{.{ .duration_seconds = 60, .last_used_at = 0 }};
    const result = try chooseWithPromptHelper(allocator, io, &environ_map, entries[0..]);
    try std.testing.expect(result == .failed);
}

test "main/deleteWithPromptHelper - maps canceled response" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    const helper_file = ".zig-test-prompt-helper-cancel.js";
    defer Dir.cwd().deleteFile(io, helper_file) catch {};
    try Dir.cwd().writeFile(io, .{
        .sub_path = helper_file,
        .data = "process.stdout.write('{\"status\":\"canceled\"}\\n');\n",
    });

    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();
    try environ_map.put(PROMPT_HELPER_ENTRY_ENV, helper_file);

    const entries = [_]history.Entry{.{ .duration_seconds = 60, .last_used_at = 0 }};
    const result = try deleteWithPromptHelper(allocator, io, &environ_map, entries[0..]);
    try std.testing.expect(result == .canceled);
}

test "main/runSetupSoundPrompt - parses submitted sound config" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    const helper_file = ".zig-test-prompt-helper-sound.js";
    defer Dir.cwd().deleteFile(io, helper_file) catch {};
    try Dir.cwd().writeFile(io, .{
        .sub_path = helper_file,
        .data = "process.stdout.write('{\"status\":\"submitted\",\"player\":\"/usr/bin/paplay\",\"file\":\"/tmp/ding.wav\"}\\n');\n",
    });

    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();
    try environ_map.put(PROMPT_HELPER_ENTRY_ENV, helper_file);

    const players = [_][]const u8{"/usr/bin/paplay"};
    const result = try runSetupSoundPrompt(allocator, io, &environ_map, players[0..]);
    switch (result) {
        .chosen => |value| {
            defer allocator.free(value.player);
            defer allocator.free(value.file);
            try std.testing.expectEqualStrings("/usr/bin/paplay", value.player);
            try std.testing.expectEqualStrings("/tmp/ding.wav", value.file);
        },
        else => try std.testing.expect(false),
    }
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

test "main/generateSocketPath - uses TMPDIR and returns unique IPC socket paths" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();
    try environ_map.put("TMPDIR", "/private/tmp/ttc-tests");

    const first = try generateSocketPath(allocator, io, &environ_map);
    defer allocator.free(first);
    const second = try generateSocketPath(allocator, io, &environ_map);
    defer allocator.free(second);

    try std.testing.expect(!std.mem.eql(u8, first, second));
    try std.testing.expect(std.mem.startsWith(u8, first, "/private/tmp/ttc-tests/tty-clock-timer-"));
    try std.testing.expect(std.mem.endsWith(u8, first, ".sock"));
}

test "main/generateSocketPath - empty TMPDIR falls back to /tmp" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();
    try environ_map.put("TMPDIR", "");

    const path = try generateSocketPath(allocator, io, &environ_map);
    defer allocator.free(path);
    try std.testing.expect(std.mem.startsWith(u8, path, "/tmp/tty-clock-timer-"));
}

test "main/generateSocketPath - overlong TMPDIR falls back to /tmp" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();
    const long_tmpdir = "/this/path/is/intentionally/too/long/for/a/portable/unix/domain/socket/address/and/must/fall/back/instead/of/failing";
    try environ_map.put("TMPDIR", long_tmpdir);

    const path = try generateSocketPath(allocator, io, &environ_map);
    defer allocator.free(path);
    try std.testing.expect(std.mem.startsWith(u8, path, "/tmp/tty-clock-timer-"));
}

test "main/clearSocketPath - removes an existing path and tolerates missing path" {
    const io = std.testing.io;
    const path = ".zig-test-stale-socket";
    Dir.cwd().deleteFile(io, path) catch {};
    var file = try Dir.cwd().createFile(io, path, .{});
    file.close(io);

    try clearSocketPath(io, path);
    try clearSocketPath(io, path);
    try std.testing.expectError(error.FileNotFound, Dir.cwd().openFile(io, path, .{}));
}

test "main/sound player candidates include macOS and Linux players" {
    try std.testing.expectEqualStrings("afplay", SOUND_PLAYER_CANDIDATES[0]);
    try std.testing.expectEqualStrings("paplay", SOUND_PLAYER_CANDIDATES[1]);
    try std.testing.expectEqualStrings("aplay", SOUND_PLAYER_CANDIDATES[3]);
}

test "main/runSetupSoundPrompt - accepts afplay selection" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    const helper_file = ".zig-test-prompt-helper-afplay.js";
    defer Dir.cwd().deleteFile(io, helper_file) catch {};
    try Dir.cwd().writeFile(io, .{
        .sub_path = helper_file,
        .data = "process.stdout.write('{\"status\":\"submitted\",\"player\":\"/usr/bin/afplay\",\"file\":\"/tmp/ding.aiff\"}\\n');\n",
    });

    var environ_map = std.process.Environ.Map.init(allocator);
    defer environ_map.deinit();
    try environ_map.put(PROMPT_HELPER_ENTRY_ENV, helper_file);

    const players = [_][]const u8{ "/usr/bin/afplay", "/usr/bin/paplay" };
    const result = try runSetupSoundPrompt(allocator, io, &environ_map, players[0..]);
    switch (result) {
        .chosen => |value| {
            defer allocator.free(value.player);
            defer allocator.free(value.file);
            try std.testing.expectEqualStrings("/usr/bin/afplay", value.player);
            try std.testing.expectEqualStrings("/tmp/ding.aiff", value.file);
        },
        else => try std.testing.expect(false),
    }
}
