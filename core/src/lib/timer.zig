const std = @import("std");

pub const TimerState = enum {
    idle,
    running,
    paused,
    finished,
};

pub const CountdownTimer = struct {
    last_tick: ?std.Io.Timestamp,
    remaining_ns: u64,
    state: TimerState,
    reset_ns: u64,

    pub fn init(duration_ns: u64) CountdownTimer {
        return .{
            .last_tick = null,
            .remaining_ns = duration_ns,
            .state = .idle,
            .reset_ns = duration_ns,
        };
    }

    pub fn start(self: *CountdownTimer, io: std.Io) !void {
        switch (self.state) {
            .idle => {
                self.state = .running;
            },
            .finished => {
                self.remaining_ns = self.reset_ns;
                self.state = .running;
            },
            .running => {
                self.remaining_ns = self.reset_ns;
            },
            .paused => {
                self.state = .running;
            },
        }

        self.last_tick = nowTimestamp(io);
    }

    pub fn pause(self: *CountdownTimer, io: std.Io) void {
        if (self.state != .running) return;

        self.update(io);
        if (self.state == .finished) return;

        self.state = .paused;
        self.last_tick = null;
    }

    pub fn unpause(self: *CountdownTimer, io: std.Io) !void {
        if (self.state != .paused) return;

        self.state = .running;
        self.last_tick = nowTimestamp(io);
    }

    pub fn update(self: *CountdownTimer, io: std.Io) void {
        if (self.state != .running) return;

        const previous_tick = self.last_tick orelse {
            self.last_tick = nowTimestamp(io);
            return;
        };

        const current_tick = nowTimestamp(io);
        const elapsed_ns = elapsedSince(previous_tick, current_tick);
        self.last_tick = current_tick;

        if (elapsed_ns >= self.remaining_ns) {
            self.remaining_ns = 0;
            self.state = .finished;
            self.last_tick = null;
            return;
        }

        self.remaining_ns -= elapsed_ns;
    }

    pub fn getFormattedTime(self: *const CountdownTimer, allocator: std.mem.Allocator) ![]u8 {
        const total_seconds = self.remaining_ns / std.time.ns_per_s;
        const minutes = total_seconds / 60;
        const seconds = total_seconds % 60;

        return std.fmt.allocPrint(allocator, "{d:0>2}:{d:0>2}", .{ minutes, seconds });
    }

    pub fn isFinished(self: *CountdownTimer) bool {
        if (self.remaining_ns == 0) {
            self.state = .finished;
            return true;
        }

        return false;
    }

    pub fn reset(self: *CountdownTimer) void {
        self.last_tick = null;
        self.remaining_ns = self.reset_ns;
        self.state = .idle;
    }
};

fn nowTimestamp(io: std.Io) std.Io.Timestamp {
    return std.Io.Timestamp.now(io, .awake);
}

fn elapsedSince(start: std.Io.Timestamp, end: std.Io.Timestamp) u64 {
    const diff_ns = start.durationTo(end).toNanoseconds();
    if (diff_ns <= 0) return 0;
    return std.math.cast(u64, diff_ns) orelse std.math.maxInt(u64);
}

fn testIo() std.Io {
    return std.Options.debug_io;
}

test "timer/init and reset - returns to idle" {
    var countdown_timer = CountdownTimer.init(5 * std.time.ns_per_s);

    try std.testing.expectEqual(TimerState.idle, countdown_timer.state);
    try std.testing.expectEqual(@as(u64, 5 * std.time.ns_per_s), countdown_timer.remaining_ns);
    try std.testing.expect(countdown_timer.last_tick == null);

    try countdown_timer.start(testIo());
    try std.testing.expectEqual(TimerState.running, countdown_timer.state);
    try std.testing.expect(countdown_timer.last_tick != null);

    countdown_timer.reset();
    try std.testing.expectEqual(TimerState.idle, countdown_timer.state);
    try std.testing.expectEqual(@as(u64, 5 * std.time.ns_per_s), countdown_timer.remaining_ns);
    try std.testing.expect(countdown_timer.last_tick == null);
}

test "timer/start - transitions and restart behavior" {
    var countdown_timer = CountdownTimer.init(5 * std.time.ns_per_s);

    try countdown_timer.start(testIo());
    try std.testing.expectEqual(TimerState.running, countdown_timer.state);

    countdown_timer.remaining_ns = 2 * std.time.ns_per_s;
    try countdown_timer.start(testIo());
    try std.testing.expectEqual(@as(u64, 5 * std.time.ns_per_s), countdown_timer.remaining_ns);

    countdown_timer.state = .finished;
    countdown_timer.remaining_ns = 0;
    try countdown_timer.start(testIo());
    try std.testing.expectEqual(TimerState.running, countdown_timer.state);
    try std.testing.expectEqual(@as(u64, 5 * std.time.ns_per_s), countdown_timer.remaining_ns);
}

test "timer/pause and unpause - state is preserved" {
    var countdown_timer = CountdownTimer.init(2 * std.time.ns_per_s);

    countdown_timer.pause(testIo());
    try std.testing.expectEqual(TimerState.idle, countdown_timer.state);

    try countdown_timer.start(testIo());
    try std.testing.expectEqual(TimerState.running, countdown_timer.state);

    countdown_timer.pause(testIo());
    try std.testing.expectEqual(TimerState.paused, countdown_timer.state);
    try std.testing.expect(countdown_timer.last_tick == null);

    const paused_ns = countdown_timer.remaining_ns;
    try countdown_timer.unpause(testIo());
    try std.testing.expectEqual(TimerState.running, countdown_timer.state);
    try std.testing.expect(countdown_timer.remaining_ns == paused_ns);
    try std.testing.expect(countdown_timer.last_tick != null);
}

test "timer/update - decreases remaining in running state" {
    var countdown_timer = CountdownTimer.init(std.time.ns_per_s);
    const io = testIo();
    try countdown_timer.start(io);

    const before = countdown_timer.remaining_ns;
    const now = nowTimestamp(io);
    countdown_timer.last_tick = now.subDuration(std.Io.Duration.fromMilliseconds(250));

    countdown_timer.update(io);

    try std.testing.expect(countdown_timer.remaining_ns < before);
    try std.testing.expectEqual(TimerState.running, countdown_timer.state);
}

test "timer/update - marks finished when elapsed exceeds remaining" {
    var countdown_timer = CountdownTimer.init(std.time.ns_per_s);
    const io = testIo();
    try countdown_timer.start(io);

    const now = nowTimestamp(io);
    countdown_timer.last_tick = now.subDuration(std.Io.Duration.fromSeconds(2));

    countdown_timer.update(io);

    try std.testing.expectEqual(@as(u64, 0), countdown_timer.remaining_ns);
    try std.testing.expectEqual(TimerState.finished, countdown_timer.state);
    try std.testing.expect(countdown_timer.last_tick == null);
}

test "timer/getFormattedTime - formats as MM:SS" {
    const allocator = std.testing.allocator;
    var countdown_timer = CountdownTimer.init(65 * std.time.ns_per_s);

    const formatted = try countdown_timer.getFormattedTime(allocator);
    defer allocator.free(formatted);

    try std.testing.expectEqualStrings("01:05", formatted);
}

test "timer/isFinished - updates state on zero" {
    var countdown_timer = CountdownTimer.init(std.time.ns_per_s);

    try std.testing.expect(!countdown_timer.isFinished());
    try std.testing.expectEqual(TimerState.idle, countdown_timer.state);

    countdown_timer.remaining_ns = 0;
    try std.testing.expect(countdown_timer.isFinished());
    try std.testing.expectEqual(TimerState.finished, countdown_timer.state);
}
