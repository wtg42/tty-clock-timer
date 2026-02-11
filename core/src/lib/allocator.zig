//! Allocator context used by core runtime.
//!
//! Policy:
//! - Debug mode uses `DebugAllocator` for leak detection.
//! - Non-Debug modes use `ArenaAllocator` for lower allocation overhead.
//!
//! `AllocatorCtx` wraps allocator creation and teardown in one RAII-style type
//! so callers can `init` once and `defer deinit` at program boundaries.

const std = @import("std");
const builtin = @import("builtin");

pub const AllocatorCtx = struct {
    /// Active in Debug mode for leak detection.
    debug_alloc: ?std.heap.DebugAllocator(.{}) = null,

    /// Active in non-Debug modes for amortized allocations.
    arena_alloc: ?std.heap.ArenaAllocator = null,

    /// Creates allocator context according to current build mode.
    pub fn init() AllocatorCtx {
        if (builtin.mode == .Debug) {
            return .{ .debug_alloc = std.heap.DebugAllocator(.{}).init };
        } else {
            return .{
                .arena_alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator),
            };
        }
    }

    /// Returns active allocator interface.
    pub fn allocator(self: *AllocatorCtx) std.mem.Allocator {
        if (builtin.mode == .Debug) {
            return self.debug_alloc.?.allocator();
        } else {
            return self.arena_alloc.?.allocator();
        }
    }

    /// Releases allocator resources; Debug mode reports leak check result.
    pub fn deinit(self: *AllocatorCtx) ?std.heap.Check {
        if (builtin.mode == .Debug) {
            return self.debug_alloc.?.deinit();
        } else {
            self.arena_alloc.?.deinit();
            return .ok;
        }
    }
};

// 測試基本功能：建立 allocator，分配記憶體，設定值，檢查值，然後清理
test "AllocatorCtx basic functionality" {
    var ctx = AllocatorCtx.init();
    defer _ = ctx.deinit();

    const data = try ctx.allocator().create(u8);
    defer ctx.allocator().destroy(data);

    data.* = 42;
    try std.testing.expectEqual(@as(u8, 42), data.*);
}

// 測試 Debug 模式：分配陣列，設定值，檢查值，釋放，確認無洩漏
test "AllocatorCtx debug mode" {
    if (builtin.mode == .Debug) {
        var ctx = AllocatorCtx.init();

        const data = try ctx.allocator().alloc(u8, 10);

        for (data, 0..) |*item, i| {
            item.* = @intCast(i);
        }

        for (data, 0..) |item, i| {
            try std.testing.expectEqual(@as(u8, @intCast(i)), item);
        }

        ctx.allocator().free(data);

        const result = ctx.deinit();
        try std.testing.expectEqual(std.heap.Check.ok, result);
    }
}

// 測試 Release 模式：分配大塊記憶體，多次分配小塊並釋放，確認無問題
test "AllocatorCtx release mode" {
    if (builtin.mode != .Debug) {
        var ctx = AllocatorCtx.init();

        const data = try ctx.allocator().alloc(u8, 1000);

        var i: usize = 0;
        while (i < 100) : (i += 1) {
            const small = try ctx.allocator().alloc(u8, 10);
            ctx.allocator().free(small);
        }

        ctx.allocator().free(data);

        const result = ctx.deinit();
        try std.testing.expectEqual(std.heap.Check.ok, result);
    }
}
