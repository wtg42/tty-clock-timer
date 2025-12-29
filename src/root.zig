//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

// 匯出子模組
pub const config = @import("lib/config.zig");
