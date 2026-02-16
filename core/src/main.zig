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
const ipc = @import("lib/ipc.zig");
const timer_mod = @import("lib/timer.zig");

const SOCKET_PATH = "/tmp/tty-clock-timer.sock";

fn helpMessage() []const u8 {
    return "Usage: tty_clock_timer [OPTIONS]\n" ++
        "\n" ++
        "Options:\n" ++
        "  -m, --minutes <num>    Set countdown minutes\n" ++
        "  -s, --seconds <num>    Set countdown seconds\n" ++
        "  -h, --help             Show this help message\n" ++
        "\n" ++
        "Example:\n" ++
        "  tty_clock_timer --minutes 25\n" ++
        "  tty_clock_timer -s 90\n";
}

fn timerStateToStatus(state: timer_mod.TimerState) []const u8 {
    return switch (state) {
        .idle => "idle",
        .running => "running",
        .paused => "paused",
        .finished => "finished",
    };
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
    writer: *Io.Writer,
    timer: *timer_mod.CountdownTimer,
    total_duration_seconds: u32,
    timer_finished_notified: *bool,
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
    try ipc.updateTimer(allocator, writer, remaining_seconds, total_duration_seconds, timerStateToStatus(timer.state));
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
        try sendTimerProjection(allocator, writer, timer, total_duration_seconds, timer_finished_notified);
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

/// Resolve TUI working directory from common launch locations.
/// Tries "tui", "../tui", "../../tui" in order.
/// Returns the first found directory path or null if none exist.
fn findUiCwd(io: Io) ?[]const u8 {
    const ui_candidates = [_][]const u8{ "tui", "../tui", "../../tui" };
    for (ui_candidates) |candidate| {
        if (Dir.cwd().openDir(io, candidate, .{})) |dir| {
            dir.close(io);
            return candidate;
        } else |_| {}
    }
    return null;
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
};

/// Prepare Unix socket server for TUI <-> core IPC bridge.
/// Clears stale socket file, initializes address, and starts listening.
fn setupSocket(io: Io, stderr_writer: *Io.Writer, socket_path: []const u8) !SocketServerContext {
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

    const server = std.Io.net.UnixAddress.listen(&socket_address, io, .{}) catch |err| {
        try stderr_writer.print("Error: Failed to listen on unix socket ({s})\n", .{@errorName(err)});
        try stderr_writer.flush();
        std.process.exit(1);
    };

    return SocketServerContext{ .server = server };
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
                socket_writer,
                countdown_timer,
                total_duration_seconds,
                timer_finished_notified,
            ) catch |err| {
                stderr_writer.print("Error: Failed to send socket timer event ({s})\n", .{@errorName(err)}) catch {};
                stderr_writer.flush() catch {};
                std.process.exit(1);
            };
        } else {
            sendTimerProjection(
                allocator,
                stdout_writer,
                countdown_timer,
                total_duration_seconds,
                timer_finished_notified,
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

    // Step 3: Configure stdin into raw mode when running in a terminal.
    // This lets us react to single-key input (`q`) without waiting for Enter.
    const raw_mode = try setupRawMode(stderr_writer);
    const stdin_is_tty = raw_mode.stdin_is_tty;
    defer if (raw_mode.original_termios) |saved| {
        std.posix.tcsetattr(Io.File.stdin().handle, .NOW, saved) catch |err| {
            stderr_writer.print("Error: Failed to restore stdin settings ({s})\n", .{@errorName(err)}) catch {};
            stderr_writer.flush() catch {};
        };
    };

    // Step 4: Parse CLI arguments and fail fast on invalid input.
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

    const total_duration_seconds = config.duration_seconds;
    const total_duration_ns = @as(u64, total_duration_seconds) * std.time.ns_per_s;

    // Step 5: Initialize and start the timer state machine.
    var countdown_timer = timer_mod.CountdownTimer.init(total_duration_ns);
    countdown_timer.start(io) catch |err| {
        try stderr_writer.print("Error: Failed to start timer ({s})\n", .{@errorName(err)});
        try stderr_writer.flush();
        std.process.exit(1);
    };

    var ui_child: ?std.process.Child = null;
    defer if (ui_child) |*child| teardownUiChild(io, child);

    var socket_server: ?std.Io.net.Server = null;
    var socket_stream: ?std.Io.net.Stream = null;
    defer {
        if (socket_stream) |stream| {
            var copy = stream;
            copy.close(io);
        }
        if (socket_server) |*server| server.deinit(io);
        clearSocketPath(io, SOCKET_PATH) catch {};
    }

    // Step 6: Resolve TUI working directory from common launch locations.
    const ui_cwd = findUiCwd(io);

    if (std.process.can_spawn and ui_cwd != null) {
        // Step 7: Prepare Unix socket server for TUI <-> core IPC bridge.
        const server_ctx = try setupSocket(io, stderr_writer, SOCKET_PATH);
        socket_server = server_ctx.server;
    }

    if (std.process.can_spawn) {
        if (ui_cwd) |cwd| {
            // Step 8: Spawn TUI child process and inject socket path argument.
            const ui_argv = &[_][]const u8{
                "bun",
                "run",
                "src/index.tsx",
                "--",
                "--socket-path",
                SOCKET_PATH,
            };
            const child_result = std.process.spawn(io, .{
                .argv = ui_argv,
                .cwd = .{ .path = cwd },
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
    const tick_duration = Io.Clock.Duration{ .clock = .awake, .raw = Io.Duration.fromSeconds(1) };
    var timer_finished_notified = false;

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
            &socket_writer.interface,
            &countdown_timer,
            total_duration_seconds,
            &timer_finished_notified,
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
        "Usage: tty_clock_timer [OPTIONS]\n\nOptions:\n  -m, --minutes <num>    Set countdown minutes\n  -s, --seconds <num>    Set countdown seconds\n  -h, --help             Show this help message\n\nExample:\n  tty_clock_timer --minutes 25\n  tty_clock_timer -s 90\n",
        helpMessage(),
    );
}
