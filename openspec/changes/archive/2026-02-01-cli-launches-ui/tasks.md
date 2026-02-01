## 1. UI 進程啟動整合

- [x] 1.1 盤點目前 CLI 啟動流程與 IPC 輸出位置
- [x] 1.2 在 CLI 主流程啟動 OpenTUI 子進程並建立 IPC 管道

## 2. 錯誤處理與清理

- [x] 2.1 UI 啟動失敗時回報錯誤並回退至 CLI 模式
- [x] 2.2 CLI 結束時確保 UI 子進程終止

## 3. Verify

- [x] 3.1 透過 CLI 啟動後 UI 能顯示 timer 更新
