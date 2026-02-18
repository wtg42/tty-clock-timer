## 1. History Storage

- [x] 1.1 新增 history data model（至少含 duration seconds、last_used_at）
- [x] 1.2 實作 XDG state 路徑解析與目錄建立
- [x] 1.3 實作 history 讀寫、去重、排序與上限裁剪
- [x] 1.4 實作損壞檔案容錯（fallback 空清單 + 診斷訊息）

## 2. CLI List Flow

- [x] 2.1 擴充 CLI 參數解析，加入 `list` 子命令
- [x] 2.2 實作 list 顯示與選擇後直接啟動 timer 流程
- [x] 2.3 實作取消與空歷史清單的使用者回饋

## 3. Gum Integration + Fallback

- [x] 3.1 實作 `gum` 查找順序（repo bundled binary → PATH）
- [x] 3.2 實作 `gum` 選單呼叫與輸出解析
- [x] 3.3 在 `gum` 不可用/失敗時切換到內建純文字選單

## 4. Verification

- [x] 4.1 新增/更新 Zig tests：history storage、CLI parsing、selection flow
- [x] 4.2 驗證 `list` 在有無 `gum` 兩種情境都可完成選擇與啟動
- [x] 4.3 執行 `zig build test`，確認既有功能未回歸
