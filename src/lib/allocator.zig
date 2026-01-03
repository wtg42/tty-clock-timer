//! Memory Allocator Management Module
//!
//! 提供統一的 allocator 介面，根據編譯模式自動選擇適當的 allocator 實作。
//! Debug 模式使用 DebugAllocator 來檢測記憶體洩漏和雙重釋放；
//! Release 模式使用 ArenaAllocator 以獲得最佳效能。
//!
//! # 設計模式
//! - RAII (Resource Acquisition Is Initialization): AllocatorCtx 結構體同時封裝 allocator 實例和對應的清理方法
//! - 明確生命週期管理: 實例儲存在結構體中，避免懸垂指標問題
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
    /// Allocator Context Structure
    ///
    /// 封裝 allocator 實例和對應的清理方法，確保記憶體管理的一致性和正確性。
    /// 此結構體儲存實際的 allocator 實例，避免懸垂指標問題。
    ///
    /// # 欄位說明
    /// - `debug_alloc`: DebugAllocator 實例（僅 Debug 模式）
    /// - `arena_alloc`: ArenaAllocator 實例（僅 Release 模式）
    ///
    /// # 使用注意事項
    /// - 必須呼叫 `deinit()` 來釋放資源和檢測洩漏
    /// - Debug 模式會檢測記憶體洩漏，返回 `.leak` 表示有洩漏
    /// - Release 模式使用 ArenaAllocator 進行批次分配，提升效能
    /// - 建議使用 `defer _ = ctx.deinit()` 確保資源釋放
    debug_alloc: ?std.heap.DebugAllocator(.{}) = null,
    arena_alloc: ?std.heap.ArenaAllocator = null,

    /// Factory function to create an allocator context based on build mode
    ///
    /// 根據編譯模式初始化適當的 allocator：
    /// - Debug 模式: 初始化 `std.heap.DebugAllocator` 來追蹤記憶體分配、檢測洩漏和雙重釋放
    /// - Release 模式: 初始化 `std.heap.ArenaAllocator` 以獲得最佳效能
    ///
    /// # 返回值
    /// 返回 `AllocatorCtx` 結構體，包含初始化的 allocator 實例
    ///
    /// # 錯誤處理
    /// 此函式不會失敗
    ///
    /// # 使用範例
    /// var ctx = AllocatorCtx.init();
    /// defer _ = ctx.deinit();
    ///
    /// const buffer = try ctx.allocator().alloc(u8, 1024);
    /// defer ctx.allocator().free(buffer);
    pub fn init() AllocatorCtx {
        if (builtin.mode == .Debug) {
            return .{ .debug_alloc = std.heap.DebugAllocator(.{}).init };
        } else {
            return .{
                .arena_alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator),
            };
        }
    }

    /// Get the allocator interface
    ///
    /// 返回標準的 Allocator 介面，可用於記憶體分配和釋放操作。
    ///
    /// # 返回值
    /// 返回 `std.mem.Allocator` 介面實例
    pub fn allocator(self: *AllocatorCtx) std.mem.Allocator {
        if (builtin.mode == .Debug) {
            return self.debug_alloc.?.allocator();
        } else {
            return self.arena_alloc.?.allocator();
        }
    }

    /// Cleanup and check for memory leaks (Debug mode)
    ///
    /// 釋放 allocator 相關資源並（在 Debug 模式下）檢測記憶體洩漏。
    ///
    /// # 返回值
    /// Debug 模式返回 `std.heap.Check`:
    /// - `.ok`: 無記憶體洩漏
    /// - `.leak`: 有記憶體洩漏
    /// Release 模式總是返回 `.ok`
    ///
    /// # 使用範例
    /// var ctx = AllocatorCtx.init();
    /// defer {
    ///     const result = ctx.deinit();
    ///     if (result == .leak) @panic("memory leak detected");
    /// }
    pub fn deinit(self: *AllocatorCtx) std.heap.Check {
        if (builtin.mode == .Debug) {
            return self.debug_alloc.?.deinit();
        } else {
            self.arena_alloc.?.deinit();
            return .ok;
        }
    }
};

test "AllocatorCtx basic functionality" {
    var ctx = AllocatorCtx.init();
    defer _ = ctx.deinit();

    const data = try ctx.allocator().create(u8);
    defer ctx.allocator().destroy(data);

    data.* = 42;
    try std.testing.expectEqual(@as(u8, 42), data.*);
}

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

test "AllocatorCtx memory leak detection (Debug only)" {
    if (builtin.mode == .Debug) {
        var ctx = AllocatorCtx.init();

        _ = try ctx.allocator().create(u8);

        const result = ctx.deinit();
        try std.testing.expectEqual(std.heap.Check.leak, result);
    }
}
