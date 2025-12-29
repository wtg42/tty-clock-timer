/// TTY Clock Timer - CLI Entry Point
///
/// 此檔案為可執行檔的入口點，負責：
/// - CLI 參數解析委派給 config 模組
/// - 記憶體管理（使用 GeneralPurposeAllocator）
/// - 錯誤處理與訊息輸出
/// - 整合核心模組（timer, ui, notify - 開發中）
const std = @import("std");
const tty_clock_timer = @import("tty_clock_timer");

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
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        // 在程式結束前檢查記憶體洩漏，如果發現則觸發 panic
        const result = gpa.deinit();
        if (result == .leak) @panic("memory leak detected");
    }
    const allocator = gpa.allocator();

    // 解析 CLI 參數，使用 catch 處理可能的錯誤
    const config = tty_clock_timer.config.parseArgs(allocator) catch |err| {
        switch (err) {
            tty_clock_timer.config.ParseError.MissingArguments => {
                std.debug.print("Error: Missing arguments. Usage: tty_clock_timer --minutes <num> | --seconds <num> | --help\n", .{});
            },
            tty_clock_timer.config.ParseError.MissingMinutesValue => {
                std.debug.print("Error: --minutes requires a numeric value\n", .{});
            },
            tty_clock_timer.config.ParseError.MissingSecondsValue => {
                std.debug.print("Error: --seconds requires a numeric value\n", .{});
            },
            tty_clock_timer.config.ParseError.UnknownArgument => {
                std.debug.print("Error: Unknown argument. Use --help for usage information\n", .{});
            },
            tty_clock_timer.config.ParseError.InvalidNumber => {
                std.debug.print("Error: Invalid numeric value provided\n", .{});
            },
            tty_clock_timer.config.ParseError.Overflow => {
                std.debug.print("Error: Numeric value too large\n", .{});
            },
            tty_clock_timer.config.ParseError.OutOfMemory => {
                std.debug.print("Error: Out of memory\n", .{});
            },
        }
        std.process.exit(1);
    };

    // 顯示使用說明訊息
    if (config.show_help) {
        std.debug.print("Usage: tty_clock_timer [OPTIONS]\n", .{});
        std.debug.print("\n", .{});
        std.debug.print("Options:\n", .{});
        std.debug.print("  -m, --minutes <num>    Set countdown minutes\n", .{});
        std.debug.print("  -s, --seconds <num>    Set countdown seconds\n", .{});
        std.debug.print("  -h, --help             Show this help message\n", .{});
        std.debug.print("\n", .{});
        std.debug.print("Example:\n", .{});
        std.debug.print("  tty_clock_timer --minutes 25\n", .{});
        std.debug.print("  tty_clock_timer -s 90\n", .{});
        return;
    }

    // TODO: 暫時印出解析結果，之後會替換成實際的倒數計時功能
    // 未來應整合 timer.zig、ui.zig、notify.zig 模組
    std.debug.print("Configuration:\n", .{});
    std.debug.print("  Duration: {} seconds\n", .{config.duration_seconds});
    std.debug.print("  Reset mode: {}\n", .{config.reset_mode});
    std.debug.print("  Show help: {}\n", .{config.show_help});
}
