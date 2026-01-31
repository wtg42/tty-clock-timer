//! Timer Module - 倒數計時邏輯與狀態管理
//!
//! 此模組提供完整的倒數計時器功能，支援狀態管理與時間格式化。
//!
//! 主要功能：
//! - 倒數計時器的核心邏輯與狀態管理（idle/running/paused/finished）
//! - 高精度時間計算與更新
//! - 時間格式化輸出（MM:SS）
//! - 非阻塞設計，適合異步應用
//!
//! 使用範例：
//! ```zig
//! const timer_mod = @import("timer.zig");
//! var timer = timer_mod.CountdownTimer.init(10_000_000_000); // 10 秒
//! try timer.start(); // 開始計時
//! while (!timer.isFinished()) {
//!     _ = timer.update(); // 更新剩餘時間
//!     // 顯示格式化時間
//!     const formatted = try timer.getFormattedTime(allocator);
//!     defer allocator.free(formatted);
//!     std.debug.print("剩餘時間: {s}\n", .{formatted});
//!     std.time.sleep(1_000_000_000); // 每秒更新
//! }
//! timer.reset(); // 重置計時器
//! ```
//!
//! 設計原則：
//! - 狀態不可變性：使用 enum 表示狀態，避免無效轉換
//! - 精確計時：使用 std.time.Timer 進行高精度計時
//! - 非阻塞設計：update() 與 isFinished() 支援異步檢查
//! - 記憶體安全：getFormattedTime() 需要外部 allocator，避免內部分配
//!
//! 完成狀態：所有功能與測試已實作 ✅

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
        // 步驟：
        // 1. 初始化欄位
        // 2. 回傳實例
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
        // 步驟：
        // 1. 依狀態選擇行為
        // 2. 更新狀態與 timer
        switch (self.state) {
            .idle, .finished => {
                self.state = .running;
                self.internal_timer = try std.time.Timer.start();
            },
            .running => {
                self.remaining_ns = self.reset_ns;
                self.internal_timer.?.reset();
            },
            .paused => {
                self.state = .running;
                self.internal_timer = try std.time.Timer.start();
            },
        }
    }

    /// 暫停正在運行的計時器
    /// 如果計時器正在運行，將其狀態改為暫停並記錄剩餘時間
    pub fn pause(self: *CountdownTimer) ?void {
        // 步驟：
        // 1. 檢查是否 running
        // 2. 記錄剩餘時間
        // 3. 切換狀態
        if (self.state == .running) {
            self.remaining_ns = self.internal_timer.?.lap();
            self.state = .paused;
        }
    }

    /// 繼續已暫停的計時器
    /// 如果計時器處於暫停狀態，將其恢復為運行狀態
    pub fn unpause(self: *CountdownTimer) !void {
        // 步驟：
        // 1. 檢查是否 paused
        // 2. 重啟 timer
        if (self.state == .paused) {
            self.state = .running;
            self.internal_timer = try std.time.Timer.start();
        }
    }

    /// 更新計時器剩餘時間
    /// 從最後一次更新開始計算經過的時間，並更新剩餘時間
    /// 如果時間已到，將剩餘時間設為 0
    pub fn update(self: *CountdownTimer) ?void {
        // 步驟：
        // 1. 檢查狀態
        // 2. 計算經過時間
        // 3. 更新剩餘時間
        if (self.state != .running) {
            return;
        }

        // 讀取目前的經過的時間 並更新剩下的時間
        const duration_time = self.internal_timer.?.lap();
        self.remaining_ns = std.math.sub(u64, self.remaining_ns, duration_time) catch 0;
    }

    /// 格式化剩餘時間為字串
    /// 回傳格式 "MM:SS"（分鐘:秒）
    /// @param allocator 記憶體分配器
    /// @return 格式化字串，呼叫者負責釋放
    pub fn getFormattedTime(self: *const CountdownTimer, allocator: std.mem.Allocator) ![]u8 {
        // 步驟：
        // 1. 換算總秒數
        // 2. 計算分與秒
        // 3. 格式化字串
        const total_seconds = self.remaining_ns / 1_000_000_000;
        const minutes = total_seconds / 60;
        const seconds = total_seconds % 60;
        return std.fmt.allocPrint(allocator, "{d:0>2}:{d:0>2}", .{ minutes, seconds });
    }

    /// 檢查計時器是否結束
    /// 若 remaining_ns <= 0，設狀態為 finished 並回傳 true
    /// @return true 若結束，false 否則
    pub fn isFinished(self: *CountdownTimer) bool {
        // 步驟：
        // 1. 判斷 remaining
        // 2. 更新狀態
        // 3. 回傳結果
        if (self.remaining_ns <= 0) {
            self.state = .finished;
            return true;
        }
        return false;
    }

    /// 重置計時器至初始狀態
    /// - 停止任何進行中的計時
    /// - 重置狀態為 idle
    /// - 恢復剩餘時間至初始值
    /// - 清理內部計時器
    pub fn reset(self: *CountdownTimer) void {
        // 步驟：
        // 1. 清理 timer
        // 2. 重設狀態
        // 3. 恢復時間
        // 清理內部計時器
        if (self.internal_timer) |_| {
            self.internal_timer.?.reset();
            self.internal_timer = null;
        }
        // 重置狀態與時間
        self.state = .idle;
        self.remaining_ns = self.reset_ns;
        self.paused_at = 0;
    }
};

test "reset functionality" {
    // 測試從 idle 狀態重置
    var countdown_timer = CountdownTimer.init(5000000000); // 5 秒（奈秒）
    try std.testing.expectEqual(countdown_timer.state, .idle);
    try std.testing.expectEqual(countdown_timer.remaining_ns, 5000000000);
    try std.testing.expect(countdown_timer.internal_timer == null);
    countdown_timer.reset();
    try std.testing.expectEqual(countdown_timer.state, .idle);
    try std.testing.expectEqual(countdown_timer.remaining_ns, 5000000000);
    try std.testing.expect(countdown_timer.internal_timer == null);

    // 測試從 running 狀態重置
    try countdown_timer.start();
    try std.testing.expectEqual(countdown_timer.state, .running);
    try std.testing.expect(countdown_timer.internal_timer != null);
    countdown_timer.reset();
    try std.testing.expectEqual(countdown_timer.state, .idle);
    try std.testing.expectEqual(countdown_timer.remaining_ns, 5000000000);
    try std.testing.expect(countdown_timer.internal_timer == null);

    // 測試從 paused 狀態重置
    try countdown_timer.start();
    _ = countdown_timer.pause(); // 忽略返回值
    try std.testing.expectEqual(countdown_timer.state, .paused);
    countdown_timer.reset();
    try std.testing.expectEqual(countdown_timer.state, .idle);
    try std.testing.expectEqual(countdown_timer.remaining_ns, 5000000000);
    try std.testing.expect(countdown_timer.internal_timer == null);
    try std.testing.expectEqual(countdown_timer.paused_at, 0);

    // 測試從 finished 狀態重置（手動設定模擬）
    countdown_timer.state = .finished;
    countdown_timer.remaining_ns = 0;
    countdown_timer.reset();
    try std.testing.expectEqual(countdown_timer.state, .idle);
    try std.testing.expectEqual(countdown_timer.remaining_ns, 5000000000);
    try std.testing.expect(countdown_timer.internal_timer == null);
}

test "start functionality" {
    // 測試從 idle 狀態啟動
    var countdown_timer = CountdownTimer.init(5000000000);
    try std.testing.expectEqual(countdown_timer.state, .idle);
    try countdown_timer.start();
    try std.testing.expectEqual(countdown_timer.state, .running);
    try std.testing.expect(countdown_timer.internal_timer != null);
    try std.testing.expectEqual(countdown_timer.remaining_ns, 5000000000);

    // 重置以進行下個測試
    countdown_timer.reset();

    // 測試從 finished 狀態啟動
    countdown_timer.state = .finished;
    try countdown_timer.start();
    try std.testing.expectEqual(countdown_timer.state, .running);
    try std.testing.expect(countdown_timer.internal_timer != null);

    // 重置
    countdown_timer.reset();

    // 測試從 running 狀態重新啟動
    try countdown_timer.start();
    try std.testing.expectEqual(countdown_timer.state, .running);
    try std.testing.expect(countdown_timer.internal_timer != null);
    // 模擬時間經過（手動降低 remaining_ns）
    countdown_timer.remaining_ns = 3000000000;
    try countdown_timer.start(); // 應重置 remaining_ns
    try std.testing.expectEqual(countdown_timer.state, .running);
    try std.testing.expectEqual(countdown_timer.remaining_ns, 5000000000);

    // 重置
    countdown_timer.reset();

    // 測試從 paused 狀態繼續
    try countdown_timer.start();
    _ = countdown_timer.pause();
    try std.testing.expectEqual(countdown_timer.state, .paused);
    try countdown_timer.start(); // 繼續
    try std.testing.expectEqual(countdown_timer.state, .running);
    try std.testing.expect(countdown_timer.internal_timer != null);
}

test "update functionality" {
    // 測試非 running 狀態更新（idle）
    var countdown_timer = CountdownTimer.init(1000000000); // 1 秒
    const original_ns = countdown_timer.remaining_ns;
    _ = countdown_timer.update();
    try std.testing.expectEqual(countdown_timer.remaining_ns, original_ns);
    try std.testing.expectEqual(countdown_timer.state, .idle);

    // 測試 running 狀態更新
    try countdown_timer.start();
    try std.testing.expectEqual(countdown_timer.state, .running);
    const before_update = countdown_timer.remaining_ns;
    _ = countdown_timer.update();
    try std.testing.expect(countdown_timer.remaining_ns < before_update);
    try std.testing.expect(countdown_timer.remaining_ns <= 1000000000);
    try std.testing.expectEqual(countdown_timer.state, .running);

    // 測試多次更新
    const before_second = countdown_timer.remaining_ns;
    _ = countdown_timer.update();
    try std.testing.expect(countdown_timer.remaining_ns < before_second);

    // 測試 paused 狀態
    countdown_timer.reset();
    try countdown_timer.start();
    _ = countdown_timer.pause();
    const paused_ns = countdown_timer.remaining_ns;
    _ = countdown_timer.update();
    try std.testing.expectEqual(countdown_timer.remaining_ns, paused_ns);
    try std.testing.expectEqual(countdown_timer.state, .paused);

    // 測試 finished 狀態（模擬）
    countdown_timer.reset();
    countdown_timer.state = .finished;
    const finished_ns = countdown_timer.remaining_ns;
    _ = countdown_timer.update();
    try std.testing.expectEqual(countdown_timer.remaining_ns, finished_ns);
    try std.testing.expectEqual(countdown_timer.state, .finished);
}

test "getFormattedTime functionality" {
    const allocator = std.testing.allocator;
    var countdown_timer = CountdownTimer.init(65000000000); // 65 秒 = 1 分 5 秒

    // 測試正常格式化
    const formatted = try countdown_timer.getFormattedTime(allocator);
    defer allocator.free(formatted);
    try std.testing.expectEqualStrings("01:05", formatted);

    // 測試零秒
    countdown_timer.remaining_ns = 0;
    const zero_formatted = try countdown_timer.getFormattedTime(allocator);
    defer allocator.free(zero_formatted);
    try std.testing.expectEqualStrings("00:00", zero_formatted);

    // 測試小於 1 分鐘
    countdown_timer.remaining_ns = 45000000000; // 45 秒
    const short_formatted = try countdown_timer.getFormattedTime(allocator);
    defer allocator.free(short_formatted);
    try std.testing.expectEqualStrings("00:45", short_formatted);

    // 測試大於 1 小時（但格式仍為 MM:SS）
    countdown_timer.remaining_ns = 3661000000000; // 1 小時 1 分 1 秒
    const long_formatted = try countdown_timer.getFormattedTime(allocator);
    defer allocator.free(long_formatted);
    try std.testing.expectEqualStrings("61:01", long_formatted); // 61 分 1 秒
}

test "isFinished functionality" {
    var countdown_timer = CountdownTimer.init(1000000000); // 1 秒

    // 測試未結束（remaining_ns > 0）
    try std.testing.expect(!countdown_timer.isFinished());
    try std.testing.expectEqual(countdown_timer.state, .idle); // 狀態不變

    // 測試邊界（remaining_ns = 1）
    countdown_timer.remaining_ns = 1;
    try std.testing.expect(!countdown_timer.isFinished());
    try std.testing.expectEqual(countdown_timer.state, .idle);

    // 測試已結束（remaining_ns = 0）
    countdown_timer.remaining_ns = 0;
    try std.testing.expect(countdown_timer.isFinished());
    try std.testing.expectEqual(countdown_timer.state, .finished);

    // 測試負數（但 u64 不可為負，改為 0）
    countdown_timer.reset(); // 重置狀態
    countdown_timer.remaining_ns = 0;
    try std.testing.expect(countdown_timer.isFinished());
    try std.testing.expectEqual(countdown_timer.state, .finished);

    // 測試從 running 狀態結束
    countdown_timer.reset();
    try countdown_timer.start();
    countdown_timer.remaining_ns = 0;
    try std.testing.expect(countdown_timer.isFinished());
    try std.testing.expectEqual(countdown_timer.state, .finished);

    // 測試從 paused 狀態結束
    countdown_timer.reset();
    try countdown_timer.start();
    _ = countdown_timer.pause();
    countdown_timer.remaining_ns = 0;
    try std.testing.expect(countdown_timer.isFinished());
    try std.testing.expectEqual(countdown_timer.state, .finished);
}
