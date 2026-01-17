#!/usr/bin/env bash
# scripts/retrieve.sh
# Usage: ./retrieve.sh <symbol>
# 把符號轉換為路徑並讀取 Zig 標準庫原始碼

# 根據你的路徑設定
ZIG_STD_PATH="$HOME/.zvm/master/lib/std"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <symbol>"
    exit 1
fi

SYMBOL="$1"

# 1. 處理常見的轉換邏輯
# 將 std.time.Timer 轉換為 std/time.zig
# 注意：這是一個簡化的邏輯，大部分 Zig 標準庫結構符合此規則
REL_PATH=$(echo "$SYMBOL" | sed 's/^std\.//' | tr '.' '/')

# 2. 尋找可能的檔案路徑
# 優先找 .zig 檔案，找不到再找目錄下的 index.zig
TARGET_FILE=""

if [ -f "$ZIG_STD_PATH/$REL_PATH.zig" ]; then
    TARGET_FILE="$ZIG_STD_PATH/$REL_PATH.zig"
elif [ -f "$ZIG_STD_PATH/$(dirname "$REL_PATH").zig" ]; then
    # 處理像 std.time.Timer 這種情況，Timer 在 time.zig 裡面
    TARGET_FILE="$ZIG_STD_PATH/$(dirname "$REL_PATH").zig"
elif [ -f "$ZIG_STD_PATH/$REL_PATH/index.zig" ]; then
    TARGET_FILE="$ZIG_STD_PATH/$REL_PATH/index.zig"
fi

# 3. 輸出結果給 AI
if [ -n "$TARGET_FILE" ] && [ -f "$TARGET_FILE" ]; then
    echo "--- Source found at: $TARGET_FILE ---"
    cat "$TARGET_FILE"
else
    echo "Error: Could not find source for symbol '$SYMBOL' in $ZIG_STD_PATH"
    exit 1
fi
