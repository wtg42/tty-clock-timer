## 1. CLI 行為調整

- [x] 1.1 調整 `core/src/lib/config.zig` 的無參數解析邏輯，讓無參數情境可進入 help 流程
- [x] 1.2 調整 `core/src/main.zig` 的輸出分支，確保無參數與 `--help` 使用同一份完整說明內容
- [x] 1.3 保持未知旗標、缺少數值、非數字輸入等錯誤語意與錯誤訊息不變

## 2. 測試與驗證

- [x] 2.1 更新 `core/src/lib/config.zig` 測試，覆蓋無參數情境為 help 語意
- [x] 2.2 更新 `core/src/main.zig` 相關測試，覆蓋錯誤訊息映射與 help 輸出一致性
- [x] 2.3 執行 `zig build test` 驗證核心行為，確認本變更未影響既有計時與 IPC 流程
