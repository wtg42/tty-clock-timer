/// TTY Clock Timer - CLI Entry Point
///
/// 此檔案為可執行檔的入口點，負責：
/// - CLI 參數解析委派給 config 模組
/// - 記憶體管理 context
/// - 錯誤處理與訊息輸出
/// - 整合核心模組（timer, ui, notify - 開發中）
const std = @import("std");
const Io = std.Io;
// const tty_clock_timer = @import("tty_clock_timer");
const allocator_ctx = @import("lib/allocator.zig");
const conf = @import("lib/config.zig");

/// 程式主入口點
///
/// 流程：
/// 1. 初始化記憶體分配器並偵測洩漏
/// 2. 解析 CLI 參數，處理各種錯誤情境
/// 3. 如果是 --help，顯示使用說明後退出
/// 4. 啟動倒數計時器（TODO: 待實作）
///
/// Returns:
///   - !void: 可能拋出錯誤，由 Zig runtime 處理
pub fn main() !void {
    // 初始化通用記憶體分配器，用於程式執行期間的記憶體配置
    var a_ctx = allocator_ctx.AllocatorCtx.init();
    defer {
        // 在程式結束前檢查記憶體洩漏，如果發現則觸發 panic
        const result = a_ctx.deinit();
        if (result == .leak) @panic("memory leak detected");
    }
    const allocator = a_ctx.allocator();

    // In order to do I/O operations we must construct an `Io` instance.
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    // 解析 CLI 參數，使用 catch 處理可能的錯誤
    const config = conf.parseArgs(allocator) catch |err| {
        switch (err) {
            conf.ParseError.MissingArguments => {
                try stdout_writer.print(
                    "Error: Missing arguments." ++
                        " Usage: tty_clock_timer --minutes <num> | --seconds <num> | --help\n",
                    .{},
                );
                try stdout_writer.flush();
            },
            conf.ParseError.MissingMinutesValue => {
                try stdout_writer.print("Error: --minutes requires a numeric value\n", .{});
                try stdout_writer.flush();
            },
            conf.ParseError.MissingSecondsValue => {
                try stdout_writer.print("Error: --seconds requires a numeric value\n", .{});
                try stdout_writer.flush();
            },
            conf.ParseError.UnknownArgument => {
                try stdout_writer.print("Error: Unknown argument. Use --help for usage information\n", .{});
                try stdout_writer.flush();
            },
            conf.ParseError.InvalidNumber => {
                try stdout_writer.print("Error: Invalid numeric value provided\n", .{});
                try stdout_writer.flush();
            },
            conf.ParseError.Overflow => {
                try stdout_writer.print("Error: Numeric value too large\n", .{});
                try stdout_writer.flush();
            },
            conf.ParseError.OutOfMemory => {
                try stdout_writer.print("Error: Out of memory\n", .{});
                try stdout_writer.flush();
            },
        }
        std.process.exit(1);
    };

    // 顯示使用說明訊息
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

    // TODO: 暫時印出解析結果，之後會替換成實際的倒數計時功能
    // 未來應整合 timer.zig、ui.zig、notify.zig 模組
    std.debug.print("Configuration:\n", .{});
    std.debug.print("  Duration: {} seconds\n", .{config.duration_seconds});
    std.debug.print("  Reset mode: {}\n", .{config.reset_mode});
    std.debug.print("  Show help: {}\n", .{config.show_help});
}
