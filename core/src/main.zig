/// TTY Clock Timer - CLI Entry Point
///
/// 此檔案為可執行檔的入口點，負責：
/// - CLI 參數解析委派給 config 模組
/// - 記憶體管理 context
/// - 錯誤處理與訊息輸出
/// - 整合核心模組（timer, ui, notify - 開發中）
const std = @import("std");
const Io = std.Io;
const Dir = std.Io.Dir;
// const tty_clock_timer = @import("tty_clock_timer");
const allocator_ctx = @import("lib/allocator.zig");
const conf = @import("lib/config.zig");
const ipc = @import("lib/ipc.zig");
const timer_mod = @import("lib/timer.zig");

/// 將 TimerState 對應到 IPC status 字串
///
/// 步驟：
/// 1. 依狀態分支
/// 2. 回傳對應字串
fn timerStateToStatus(state: timer_mod.TimerState) []const u8 {
    return switch (state) {
        .idle => "idle",
        .running => "running",
        .paused => "paused",
        .finished => "finished",
    };
}

/// 釋放 IPC Message 中的動態字串
///
/// 步驟：
/// 1. 依訊息類型判斷
/// 2. 釋放對應欄位
fn freeMessage(allocator: std.mem.Allocator, message: ipc.Message) void {
    switch (message) {
        .update_timer => |payload| allocator.free(payload.status),
        .keyboard_input => |payload| allocator.free(payload.key),
        else => {},
    }
}

fn configErrorMessage(err: conf.ParseError) []const u8 {
    return switch (err) {
        conf.ParseError.MissingArguments => "Error: Missing arguments. Usage: tty_clock_timer --minutes <num> | --seconds <num> | --help\n",
        conf.ParseError.MissingMinutesValue => "Error: --minutes requires a numeric value\n",
        conf.ParseError.MissingSecondsValue => "Error: --seconds requires a numeric value\n",
        conf.ParseError.UnknownArgument => "Error: Unknown argument. Use --help for usage information\n",
        conf.ParseError.InvalidNumber => "Error: Invalid numeric value provided\n",
        conf.ParseError.Overflow => "Error: Numeric value too large\n",
        conf.ParseError.OutOfMemory => "Error: Out of memory\n",
    };
}

/// 從 stdin reader 解析輸入並判斷是否退出
///
/// 步驟：
/// 1. 讀取 buffered 資料並找換行
/// 2. 解析為鍵盤訊息或 JSON
/// 3. 判斷是否觸發退出
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
        defer freeMessage(allocator, parsed);
        switch (parsed) {
            .keyboard_input => |payload| if (ipc.handleKeyboardInput(payload.key)) return true,
            else => {},
        }
    }
}

/// 程式主入口點
///
/// 流程：
/// 1. 初始化記憶體分配器並偵測洩漏
/// 2. 解析 CLI 參數，處理各種錯誤情境
/// 3. 如果是 --help，顯示使用說明後退出
/// 4. 啟動倒數計時器並進入主迴圈（包含 IPC 更新）
///
/// Returns:
///   - !void: 可能拋出錯誤，由 Zig runtime 處理
pub fn main(init: std.process.Init) !void {
    // 初始化通用記憶體分配器，用於程式執行期間的記憶體配置
    var a_ctx = allocator_ctx.AllocatorCtx.init();
    defer {
        // 在程式結束前檢查記憶體洩漏，如果發現則觸發 panic
        const result = a_ctx.deinit();
        if (result == .leak) @panic("memory leak detected");
    }
    const allocator = a_ctx.allocator();

    // In order to do I/O operations we must construct an `Io` instance.
    var threaded: std.Io.Threaded = .init(allocator, .{
        .environ = init.minimal.environ,
    });
    defer threaded.deinit();
    const io = threaded.io();

    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    var stderr_buffer: [1024]u8 = undefined;
    var stderr_file_writer: Io.File.Writer = .init(.stderr(), io, &stderr_buffer);
    const stderr_writer = &stderr_file_writer.interface;

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
    const stdin_is_tty = stdin_termios != null;
    defer if (original_termios) |saved| {
        std.posix.tcsetattr(stdin_handle, .NOW, saved) catch |err| {
            stderr_writer.print("Error: Failed to restore stdin settings ({s})\n", .{@errorName(err)}) catch {};
            stderr_writer.flush() catch {};
        };
    };

    // 解析 CLI 參數，使用 catch 處理可能的錯誤
    // 步驟：
    // 1. 解析參數
    // 2. 輸出錯誤訊息
    // 3. 以錯誤碼退出
    const config = conf.parseArgs(allocator, init.minimal) catch |err| {
        try stdout_writer.print("{s}", .{configErrorMessage(err)});
        try stdout_writer.flush();
        std.process.exit(1);
    };

    // 顯示使用說明訊息
    // 步驟：
    // 1. 輸出 help 內容
    // 2. flush
    // 3. return
    if (config.show_help) {
        try stdout_writer.print("Usage: tty_clock_timer [OPTIONS]\n", .{});
        try stdout_writer.print("\n", .{});
        try stdout_writer.print("Options:\n", .{});
        try stdout_writer.print("  -m, --minutes <num>    Set countdown minutes\n", .{});
        try stdout_writer.print("  -s, --seconds <num>    Set countdown seconds\n", .{});
        try stdout_writer.print("  -h, --help             Show this help message\n", .{});
        try stdout_writer.print("\n", .{});
        try stdout_writer.print("Example:\n", .{});
        try stdout_writer.print("  tty_clock_timer --minutes 25\n", .{});
        try stdout_writer.print("  tty_clock_timer -s 90\n", .{});
        try stdout_writer.flush();
        return;
    }

    const total_duration_seconds = config.duration_seconds;
    const total_duration_ns = @as(u64, total_duration_seconds) * std.time.ns_per_s;

    var countdown_timer = timer_mod.CountdownTimer.init(total_duration_ns);
    countdown_timer.start(io) catch |err| {
        try stderr_writer.print("Error: Failed to start timer ({s})\n", .{@errorName(err)});
        try stderr_writer.flush();
        std.process.exit(1);
    };

    var ipc_writer = stdout_writer;
    var ui_child: ?std.process.Child = null;
    defer if (ui_child) |*child| child.kill(io);

    var ui_stdin_buffer: [1024]u8 = undefined;
    var ui_stdin_writer: Io.File.Writer = undefined;

    const ui_candidates = [_][]const u8{ "tui", "../tui", "../../tui" };
    const ui_cwd: ?[]const u8 = blk: {
        for (ui_candidates) |candidate| {
            if (Dir.cwd().openDir(io, candidate, .{})) |dir| {
                dir.close(io);
                break :blk candidate;
            } else |_| {}
        }

        break :blk null;
    };

    if (std.process.can_spawn) {
        if (ui_cwd) |cwd| {
            const ui_argv = &[_][]const u8{ "bun", "run", "src/index.tsx" };
            const child_result = std.process.spawn(io, .{
                .argv = ui_argv,
                .cwd = .{ .path = cwd },
                .stdin = .pipe,
                .stdout = .inherit,
                .stderr = .inherit,
            });

            if (child_result) |child| {
                if (child.stdin) |stdin_file| {
                    ui_stdin_writer = .init(stdin_file, io, &ui_stdin_buffer);
                    ipc_writer = &ui_stdin_writer.interface;
                    ui_child = child;
                } else {
                    try stderr_writer.print("Error: UI stdin unavailable\n", .{});
                    try stderr_writer.flush();
                    var child_cleanup = child;
                    child_cleanup.kill(io);
                }
            } else |err| {
                try stderr_writer.print("Error: Failed to start UI ({s})\n", .{@errorName(err)});
                try stderr_writer.print("UI argv[0]: {s}\n", .{ui_argv[0]});
                var cwd_buffer: [std.fs.max_path_bytes]u8 = undefined;
                const cwd_dir = Dir.cwd();
                const cwd_len = Io.Dir.realPath(cwd_dir, io, &cwd_buffer) catch |e| {
                    try stderr_writer.print("Current directory: <unknown> ({s})\n", .{@errorName(e)});
                    try stderr_writer.flush();
                    return;
                };
                try stderr_writer.print("Current directory: {s}\n", .{cwd_buffer[0..cwd_len]});
                try stderr_writer.flush();
            }
        } else {
            try stderr_writer.print("Error: UI directory not found\n", .{});
            var cwd_buffer: [std.fs.max_path_bytes]u8 = undefined;
            const cwd_dir = Dir.cwd();
            const cwd_len = Io.Dir.realPath(cwd_dir, io, &cwd_buffer) catch |e| {
                try stderr_writer.print("Current directory: <unknown> ({s})\n", .{@errorName(e)});
                try stderr_writer.flush();
                return;
            };
            try stderr_writer.print("Current directory: {s}\n", .{cwd_buffer[0..cwd_len]});
            try stderr_writer.print("Tried paths:\n", .{});
            for (ui_candidates) |candidate| {
                try stderr_writer.print("  - {s}\n", .{candidate});
            }
            try stderr_writer.flush();
        }
    }

    var stdin_buffer: [1024]u8 = undefined;
    var stdin_reader: Io.File.Reader = .initStreaming(.stdin(), io, &stdin_buffer);
    var stdin_pollfds = [_]std.posix.pollfd{.{
        .fd = Io.File.stdin().handle,
        .events = std.posix.POLL.IN,
        .revents = 0,
    }};

    const tick_duration = Io.Clock.Duration{
        .clock = .awake,
        .raw = Io.Duration.fromSeconds(1),
    };

    var timer_finished_notified = false;

    // 主循環
    // 步驟：
    // 1. 輪詢 stdin
    // 2. 更新 timer 並送 IPC
    // 3. sleep 1 秒
    while (true) {
        const poll_ready = std.posix.poll(stdin_pollfds[0..], 0) catch |err| {
            try stderr_writer.print("Error: Failed to poll stdin ({s})\n", .{@errorName(err)});
            try stderr_writer.flush();
            std.process.exit(1);
        };
        if (poll_ready > 0 and (stdin_pollfds[0].revents & std.posix.POLL.IN) != 0) {
            stdin_reader.interface.fillMore() catch |err| switch (err) {
                error.EndOfStream => {},
                error.ReadFailed => {
                    try stderr_writer.print("Error: Failed to read stdin ({s})\n", .{@errorName(err)});
                    try stderr_writer.flush();
                    std.process.exit(1);
                },
            };
        }
        if (stdin_reader.interface.bufferedLen() > 0) {
            if (try handleStdinInput(allocator, &stdin_reader.interface, stdin_is_tty)) {
                ipc.sendExit(allocator, ipc_writer) catch |err| {
                    try stderr_writer.print("Error: Failed to send exit message ({s})\n", .{@errorName(err)});
                    try stderr_writer.flush();
                    std.process.exit(1);
                };
                try ipc_writer.flush();
                return;
            }
        }

        countdown_timer.update(io);
        const finished = countdown_timer.isFinished();

        if (finished) {
            // Send timer_finished notification only once
            if (!timer_finished_notified) {
                ipc.notifyTimerFinished(allocator, ipc_writer, total_duration_seconds) catch |err| {
                    try stderr_writer.print("Error: Failed to send timer finished message ({s})\n", .{@errorName(err)});
                    try stderr_writer.flush();
                    std.process.exit(1);
                };
                try ipc_writer.flush();
                timer_finished_notified = true;
            }
            // Continue loop to handle user input, don't send update_timer or exit
        } else {
            // Only send update_timer when not finished
            const remaining_seconds = @as(u32, @intCast(countdown_timer.remaining_ns / std.time.ns_per_s));
            ipc.updateTimer(allocator, ipc_writer, remaining_seconds, total_duration_seconds, timerStateToStatus(countdown_timer.state)) catch |err| {
                try stderr_writer.print("Error: Failed to send timer update ({s})\n", .{@errorName(err)});
                try stderr_writer.flush();
                std.process.exit(1);
            };
            try ipc_writer.flush();
        }

        Io.Clock.Duration.sleep(tick_duration, io) catch |err| {
            try stderr_writer.print("Error: Failed to sleep ({s})\n", .{@errorName(err)});
            try stderr_writer.flush();
            std.process.exit(1);
        };
    }
}

test "configErrorMessage - mapping" {
    try std.testing.expectEqualStrings(
        "Error: Missing arguments. Usage: tty_clock_timer --minutes <num> | --seconds <num> | --help\n",
        configErrorMessage(conf.ParseError.MissingArguments),
    );
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
