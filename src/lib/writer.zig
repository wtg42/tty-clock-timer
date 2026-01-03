const std = @import("std");

/// 本 app 使用的 Writer
pub const Writer = struct {
    io: std.Io.Threaded,
    buffer: [1024]u8,
    stdout_writer: std.Io.File.Writer,

    pub fn init(alloctor: std.mem.Allocator) !Writer {
        const io = std.Io.Threaded.init(alloctor);
        const buf: [1024]u8 = undefined;
        const writer = std.Io.File.stdout().writer(io, buf);

        var wr = Writer{};
        wr.io = io;
        wr.buffer = buf;
        wr.stdout_writer = writer;

        return wr;
    }
};

pub fn deinit(w: *Writer) void {
    w.io.deinit();
}
