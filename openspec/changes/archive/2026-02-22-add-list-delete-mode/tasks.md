## 1. CLI 參數解析

- [x] 1.1 修改 config.zig 的 Command 枚舉，新增 `list_delete` 值
- [x] 1.2 修改 parseArgsFromSlice 函數，識別 `list --delete` 參數組合
- [x] 1.3 新增測試：驗證 "list --delete" 被正確解析為 Command.list_delete
- [x] 1.4 新增測試：驗證 "list" 單獨參數仍被解析為 Command.list

## 2. 歷史記錄刪除邏輯

- [x] 2.1 修改 history.zig，新增 deleteEntriesByLabels(entries, to_delete_labels) 函數
- [x] 2.2 實現篩選邏輯：移除匹配 to_delete_labels 的 entries
- [x] 2.3 實現排序邏輯：刪除後保持 last_used_at 倒序
- [x] 2.4 新增測試：驗證刪除單個項目
- [x] 2.5 新增測試：驗證刪除多個項目
- [x] 2.6 新增測試：驗證刪除全部項目後返回空陣列

## 3. 多選刪除流程

- [x] 3.1 修改 main.zig，新增 deleteWithGum 函數（類似 chooseWithGum，但用 --no-limit）
- [x] 3.2 實現 gum choose --no-limit 命令行構建
- [x] 3.3 實現多行輸出解析（按 '\n' 分割，逐行匹配 formatDurationLabel）
- [x] 3.4 實現選中項與 entries 的匹配邏輯
- [x] 3.5 在主程式流程中處理 Command.list_delete：呼叫 deleteWithGum、保存、輸出結果
- [x] 3.6 實現「no history」輸出（空歷史、全選刪除、使用者取消時）

## 4. 邊界情況處理

- [x] 4.1 修改 resolveDurationFromHistory，區分 Command.list 和 Command.list_delete 的流程
- [x] 4.2 修改 main 函數，處理 list_delete 命令不啟動 timer（只刪除並輸出）
- [x] 4.3 處理 gum 失敗情況（輸出錯誤訊息或無降級方案）
- [x] 4.4 處理歷史檔案不存在或無效的情況

## 5. 幫助訊息與文檔

- [x] 5.1 修改 helpMessage 函數，加入 `list --delete` 使用說明
- [x] 5.2 檢查更新 CLAUDE.md 或其他文檔（如需要）

## 6. 整體測試與驗證

- [x] 6.1 執行 `zig build test` 確保所有單元測試通過
- [x] 6.2 手動測試：執行 `list --delete` 確保 gum 多選介面展示
- [x] 6.3 手動測試：選擇多個項目並驗證刪除結果
- [x] 6.4 手動測試：驗證「no history」輸出（空歷史、全選、取消情況）
- [x] 6.5 手動測試：驗證刪除後的歷史記錄排序正確
- [x] 6.6 驗證 list 原有功能未受影響
