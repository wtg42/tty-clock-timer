//! By convention, root.zig is the root source file when making a library.
//!
//! 說明：
//! - 提供 library 入口與模組彙整
//! - 目前尚未對外匯出模組
const std = @import("std");

// TODO: 匯出子模組 目前先不使用模組
// pub const config = @import("lib/config.zig");
