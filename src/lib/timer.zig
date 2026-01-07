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
//! TODO: ⚠️ Step 3: 實作 timer.zig - 部分完成
//! - TimerState enum 與 CountdownTimer struct 已定義
//! - init() 已實作
//! - 待完成：
//!   - start() - 啟動計時器
//!   - update() - 更新剩餘時間（目前是空函式）
//!   - reset() - 重置計時器
//!   - getFormattedTime() - 格式化時間輸出
//!   - isFinished() - 檢查是否結束
//!   - 測試案例

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
    internal_timer: ?std.time.Timer,
    remaining_ms: u32,
    state: TimerState,

    pub fn init(duration_ms: u32) CountdownTimer {
        return .{
            .internal_timer = null,
            .remaining_ms = duration_ms,
            .state = .idle,
        };
    }

    pub fn start(self: *CountdownTimer) !void {
        switch (self.state) {
            .idle, .finished => {
                self.state = .running;
                self.internal_timer = try .start();
            },
            .running => {
                self.internal_timer = self.internal_timer.?.reset();
            },
            .paused => {
                // TODO: 實作暫停時間
            },
        }
    }

    // update the remaining time
    pub fn update(self: *CountdownTimer) !void {
        if (self.state != .running) {
            return;
        }
        self.internal_timer.read();
    }
};
