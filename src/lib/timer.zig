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
/// - remaining_ns: Remaining time in milliseconds
/// - state: Current timer state
/// - reset_ns: The start time
pub const CountdownTimer = struct {
    internal_timer: ?std.time.Timer,
    remaining_ns: u64,
    state: TimerState,
    reset_ns: u64,
    paused_at: u64,

    /// 初始化倒數計時器
    /// @param duration_ns 初始持續時間（奈秒）
    /// @return 新的 CountdownTimer 實例
    pub fn init(duration_ns: u64) CountdownTimer {
        return .{
            .internal_timer = null,
            .remaining_ns = duration_ns,
            .state = .idle,
            .reset_ns = duration_ns,
            .paused_at = 0,
        };
    }

    /// 開始或重新開始計時器
    /// 根據當前狀態執行不同的操作：
    /// - idle/finished: 開始新的計時
    /// - running: 重置並重新開始
    /// - paused: 繼續計時
    pub fn start(self: *CountdownTimer) !void {
        switch (self.state) {
            .idle, .finished => {
                self.state = .running;
                self.internal_timer = try .start();
            },
            .running => {
                self.remaining_ns = self.reset_ns;
                self.internal_timer.?.reset();
            },
            .paused => {
                self.state = .running;
                self.internal_timer = try .start();
            },
        }
    }

    /// 暫停正在運行的計時器
    /// 如果計時器正在運行，將其狀態改為暫停並記錄剩餘時間
    pub fn pause(self: *CountdownTimer) ?void {
        if (self.state == .running) {
            self.remaining_ns = self.internal_timer.?.lap();
            self.state = .paused;
        }
    }

    /// 繼續已暫停的計時器
    /// 如果計時器處於暫停狀態，將其恢復為運行狀態
    pub fn unpause(self: *CountdownTimer) !void {
        if (self.state == .paused) {
            self.state = .running;
            self.internal_timer = try .start();
        }
    }

    /// 更新計時器剩餘時間
    /// 從最後一次更新開始計算經過的時間，並更新剩餘時間
    /// 如果時間已到，將剩餘時間設為 0
    pub fn update(self: *CountdownTimer) ?void {
        if (self.state != .running) {
            return;
        }

        // 讀取目前的經過的時間 並更新剩下的時間
        const duration_time = self.internal_timer.?.lap();
        self.remaining_ns = std.math.sub(u64, self.remaining_ns, duration_time) catch 0;
    }

    /// Reset timer 功能
    pub fn reset(self: *CountdownTimer) ?void {
        self.internal_timer.?.reset();

        return;
    }
};

test "timer basic functionality" {
    var timer_instance = try std.time.Timer.start();
    std.debug.print("started -> {any}\n privous -> {any}\n", .{ timer_instance.started, timer_instance.previous });

    const allocator = std.testing.allocator;
    // const buf = try allocator.alloc(u8, 1000);
    // defer allocator.free(buf);

    var threaded: std.Io.Threaded = .init(allocator, .{
        .environ = std.process.Environ.empty,
    });
    const io = threaded.io();

    const io_duration = std.Io.Duration.fromNanoseconds(1_000_000_000);

    try std.Io.sleep(
        io,
        io_duration,
        .real,
    );

    timer_instance.reset();
    std.debug.print("started -> {any}\n privous -> {any}\n", .{ timer_instance.started, timer_instance.previous });
}
