/// IPC 通訊模組 - 與 Node.js OpenTUI 進程的通訊管理
///
/// 負責 JSON via stdout/stdin 的 IPC 協議實作。
/// 發送訊息到 OpenTUI 使用 stdout，接收使用 stdin（過濾用戶輸入）。
///
/// 重構計劃：
/// 1. 添加 IPC 核心結構：訊息類型、訊息結構，使用 std.json 序列化/反序列化
/// 2. 實現 IPC 通訊函數：sendMessage, receiveAndFilterMessage, updateTimer, notifyTimerFinished, sendExit, handleKeyboardInput
/// 3. 錯誤處理：失敗時 panic 並印出訊息，無重試機制
/// 4. 更新測試：簡單 Unit Test 驗證 JSON 處理和過濾邏輯
/// 5. 安全性：限制用戶輸入為預定義鍵盤訊息（例如 'q' for quit）以防止惡意注入
///
/// 訊息類型：
/// - update_timer: {type, remaining_seconds, total_duration, status}
/// - timer_finished: {type, total_duration}
/// - exit: {type}
/// - keyboard_input: {type, key} (用戶輸入，綁定特定鍵)
///
const std = @import("std");

/// IPC 訊息類型
pub const MessageType = enum {
    update_timer,
    timer_finished,
    exit,
    keyboard_input,
};

/// IPC 訊息結構
pub const Message = union(MessageType) {
    update_timer: struct {
        remaining_seconds: u32,
        total_duration: u32,
        status: []const u8, // e.g., "running", "finished"
    },
    timer_finished: struct {
        total_duration: u32,
    },
    exit: void,
    keyboard_input: struct {
        key: []const u8, // e.g., "q"
    },
};

// TODO: 實作 std.json 序列化函數，將 Message 轉為 JSON 字串

// TODO: 實作 std.json 反序列化函數，將 JSON 字串轉為 Message

/// 發送訊息到 stdout
/// @param allocator 記憶體分配器
/// @param message 要發送的訊息
pub fn sendMessage(allocator: std.mem.Allocator, message: Message) !void {
    _ = allocator;
    _ = message;
    // TODO: 序列化 message 為 JSON，並寫入 stdout
}

/// 從 stdin 接收並過濾訊息
/// @param allocator 記憶體分配器
/// @return 解析的訊息或鍵盤輸入
pub fn receiveAndFilterMessage(allocator: std.mem.Allocator) !Message {
    _ = allocator;
    // TODO: 從 stdin 讀取輸入，嘗試解析為 JSON；若失敗，檢查是否為預定義鍵盤訊息
    // TODO: 只接受有效 JSON 或特定鍵（如 'q'），拒絕其他以防注入
    return Message{ .exit = {} };
}

/// 更新計時器訊息
/// @param allocator 記憶體分配器
/// @param remaining_seconds 剩餘秒數
/// @param total_duration 總持續時間
/// @param status 狀態字串
pub fn updateTimer(allocator: std.mem.Allocator, remaining_seconds: u32, total_duration: u32, status: []const u8) !void {
    _ = allocator;
    _ = remaining_seconds;
    _ = total_duration;
    _ = status;
    // TODO: 建立 update_timer 訊息並發送
}

/// 通知計時器完成
/// @param allocator 記憶體分配器
/// @param total_duration 總持續時間
pub fn notifyTimerFinished(allocator: std.mem.Allocator, total_duration: u32) !void {
    _ = allocator;
    _ = total_duration;
    // TODO: 建立 timer_finished 訊息並發送
}

/// 發送退出訊息
/// @param allocator 記憶體分配器
pub fn sendExit(allocator: std.mem.Allocator) !void {
    _ = allocator;
    // TODO: 建立 exit 訊息並發送
}

/// 處理鍵盤輸入
/// @param key 鍵字串
/// @return 是否處理成功
pub fn handleKeyboardInput(key: []const u8) bool {
    _ = key;
    // TODO: 檢查 key 是否為允許的鍵（如 'q'），並執行相應動作
    return false;
}

test "sendMessage serialization" {
    // TODO: 測試訊息序列化為 JSON
}

test "receiveAndFilterMessage parsing" {
    // TODO: 測試從字串解析訊息
}

test "receiveAndFilterMessage keyboard filtering" {
    // TODO: 測試鍵盤輸入過濾（接受 'q'，拒絕其他）
}

test "updateTimer message" {
    // TODO: 測試 updateTimer 函數發送正確訊息
}

test "notifyTimerFinished message" {
    // TODO: 測試 notifyTimerFinished 函數發送正確訊息
}

test "sendExit message" {
    // TODO: 測試 sendExit 函數發送正確訊息
}

test "handleKeyboardInput" {
    // TODO: 測試鍵盤輸入處理
}
