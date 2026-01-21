//! Memory Allocator Management Module
//!
//! 提供統一的 allocator 介面，根據編譯模式自動選擇適當的 allocator 實作。
//! Debug 模式使用 DebugAllocator 來檢測記憶體洩漏和雙重釋放；
//! Release 模式使用 ArenaAllocator 以獲得最佳效能。
//!
//! # 設計模式
//! - RAII (Resource Acquisition Is Initialization): AllocatorCtx 結構體同時封裝 allocator 實例和對應的清理方法
//! - 明確生命週期管理: 實例儲存在結構體中，避免空指標問題
//!
//! # 使用範例
//! const AllocatorCtx = @import("allocator.zig");
//!
//! pub fn main() !void {
//!     var ctx = AllocatorCtx.init();
//!     defer _ = ctx.deinit();
//!
//!     const data = try ctx.allocator().create(u8);
//!     defer ctx.allocator().destroy(data);
//! }

const std = @import("std");
const builtin = @import("builtin");

pub const AllocatorCtx = struct {
    // 這個結構體管理記憶體分配器，根據編譯模式選擇不同的 allocator
    // 欄位使用可選類型，因為不同模式只用一個

    /// Debug 模式的 allocator，用來檢查記憶體洩漏（只在 Debug 模式使用）
    debug_alloc: ?std.heap.DebugAllocator(.{}) = null,

    /// Release 模式的 allocator，用來高效分配記憶體（只在 Release 模式使用）
    arena_alloc: ?std.heap.ArenaAllocator = null,

    // 建立 allocator 上下文，根據編譯模式選擇合適的 allocator
    // Debug 模式：用來檢查記憶體問題
    // Release 模式：用來快速分配記憶體
    pub fn init() AllocatorCtx {
        if (builtin.mode == .Debug) {
            // Debug 模式：使用 DebugAllocator 來檢查記憶體洩漏
            return .{ .debug_alloc = std.heap.DebugAllocator(.{}).init };
        } else {
            // Release 模式：使用 ArenaAllocator 來高效分配
            return .{
                .arena_alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator),
            };
        }
    }

    // 取得標準的記憶體分配器介面，用來分配和釋放記憶體
    pub fn allocator(self: *AllocatorCtx) std.mem.Allocator {
        if (builtin.mode == .Debug) {
            // 返回 DebugAllocator 的介面
            return self.debug_alloc.?.allocator();
        } else {
            // 返回 ArenaAllocator 的介面
            return self.arena_alloc.?.allocator();
        }
    }

    // 清理 allocator 資源，並在 Debug 模式檢查是否有記憶體洩漏
    // 返回值：Debug 模式返回檢查結果，Release 模式返回 .ok
    pub fn deinit(self: *AllocatorCtx) ?std.heap.Check {
        if (builtin.mode == .Debug) {
            // Debug 模式：檢查洩漏並清理
            return self.debug_alloc.?.deinit();
        } else {
            // Release 模式：清理並返回無問題
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
