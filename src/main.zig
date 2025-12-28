const std = @import("std");
const tty_clock_timer = @import("tty_clock_timer");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const result = gpa.deinit();
        if (result == .leak) @panic("memory leak detected");
    }
    const allocator = gpa.allocator();

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
        }
        std.process.exit(1);
    };

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

    // 暫時印出解析結果，之後會替換成實際的倒數功能
    std.debug.print("Configuration:\n", .{});
    std.debug.print("  Duration: {} seconds\n", .{config.duration_seconds});
    std.debug.print("  Reset mode: {}\n", .{config.reset_mode});
    std.debug.print("  Show help: {}\n", .{config.show_help});
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
