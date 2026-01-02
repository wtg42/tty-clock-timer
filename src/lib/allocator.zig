// allocator.zig
const std = @import("std");
const builtin = @import("builtin");

pub const AllocatorCtx = struct {
    allocator: std.mem.Allocator,
    deinit: fn () void,
};

pub fn makeAllocator() AllocatorCtx {
    if (builtin.mode == .Debug) {
        var dbg = std.heap.DebugAllocator(.{}){};
        return .{
            .allocator = dbg.allocator(),
            .deinit = dbg.deinit,
        };
    } else {
        return .{
            .allocator = std.heap.page_allocator,
            .deinit = struct {
                fn noop() void {}
            }.noop,
        };
    }
}
