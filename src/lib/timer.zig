//! Timer Module - 倒數計時邏輯與狀態管理
//!
//! 此模組負責：
//! - 倒數計時器的核心邏輯
//! - 狀態管理（idle/running/finished）
//! - 時間計算與更新
//! - 與 UI 模組的狀態同步
//!
//! 設計原則：
//! - 狀態不可變性：使用 enum 表示狀態
//! - 精確計時：使用 std.time 進行高精度計時
//! - 非阻塞設計：支援異步檢查與更新

const std = @import("std");
const timer = std.time.Timer;

/// Timer state enumeration
/// - idle: Timer is not running
/// - running: Timer is actively counting down
/// - paused: Timer is paused
/// - finished: Timer has reached zero
pub const TimerState = enum {
    idle,
    running,
    paused,
    finished,
};

/// Timer structure representing a countdown timer
/// Fields:
/// - internal_timer: std.time.Timer
/// - remaining_ms: Remaining time in milliseconds
/// - state: Current timer state
/// - last_tick_ms: Timestamp of last update in nanoseconds
pub const CountdownTimer = struct {
    internal_timer: timer,
    remaining_ms: u32,
    state: TimerState,

    pub fn init(duration_ms: u32) !CountdownTimer {
        return .{
            .internal_timer = try timer.start(),
            .remaining_ms = duration_ms,
            .state = .idle,
        };
    }
};

pub fn update() !void {
    //
}
