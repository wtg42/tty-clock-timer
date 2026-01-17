#!/usr/bin/env bash
# scripts/search.sh
# Usage: ./search.sh <keyword>
# 用於模糊搜尋 Zig 標準庫中的相關檔案或符號

ZIG_STD_PATH="$HOME/.zvm/master/lib/std"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <keyword>"
    exit 1
fi

KEYWORD="$1"

echo "--- Searching for '$KEYWORD' in Zig Standard Library ---"

# 1. 搜尋檔名包含關鍵字的檔案 (例如搜尋 "array" 會找到 array_list.zig)
echo "[Matching Files]"
find "$ZIG_STD_PATH" -maxdepth 3 -name "*$KEYWORD*" -type f | sed "s|$ZIG_STD_PATH/||" | head -n 10

echo ""

# 2. 搜尋程式碼中包含 pub fn 或 pub const 的定義 (模糊搜尋符號)
echo "[Matching Symbols/Definitions]"
grep -rnE "pub (fn|const|type|struct|enum) [^ ]*$KEYWORD" "$ZIG_STD_PATH" \
    --include="*.zig" \
    | head -n 15 \
    | sed "s|$ZIG_STD_PATH/||"

# 提示 AI 接下來可以用 retrieve.sh
echo ""
echo "Tip: Use ./retrieve.sh <path_or_symbol> to see full content."
