# 整合計劃書 - Timer IPC 整合

## 專案背景

tty-clock-timer 是一個 Linux terminal 倒數計時器專案，目前已完成 CLI 參數解析、Timer 核心邏輯、IPC 通信模組等基礎組件。本計劃書針對將 Timer 與 IPC 模組進行整合，使計時器能夠通過 IPC 與 Node.js OpenTUI UI 進行實時通信。

## 當前狀態分析

### ✅ 已完成模組
- **timer.zig**: 完整的倒數計時器邏輯，支援狀態管理（idle/running/paused/finished）、高精度計時、時間格式化
- **ipc.zig**: 完整的 IPC 通信模組，支援 JSON 消息發送/接收，包含 timer update、finished、exit、keyboard_input 等消息類型
- **config.zig**: CLI 參數解析，支援 --minutes/--seconds 設定
- **allocator.zig**: 統一的記憶體管理上下文

### ❌ 需要整合的部分
- **main.zig**: 目前僅解析配置並列印，尚未整合 timer 和 IPC

## 整合目標

實現 Zig 主程序與 Node.js OpenTUI UI 的完整通信流程：

```
CLI 參數解析 → 創建 Timer → 啟動倒數 → IPC 更新 UI → 處理鍵盤輸入 → 計時結束通知
```

## 技術架構

```
main.zig (入口點)
├── config.zig (參數解析)
├── timer.zig (計時邏輯)
├── ipc.zig (通信協議)
└── allocator.zig (記憶體管理)
```

## 實作計劃

### Phase 1: 基礎整合 (1天)
1. **直接匯入模組** - 在 main.zig 中匯入 timer.zig 和 ipc.zig
2. **整合主循環** - 實現計時器 + IPC 的主事件循環
3. **實現狀態同步** - 確保 timer 狀態通過 IPC 與 UI 同步

### Phase 2: 功能完善 (1天)
1. **鍵盤輸入處理** - 支援 'q' 退出
2. **錯誤處理** - 完善 IPC 通信錯誤處理
3. **資源管理** - 確保計時器和 IPC 資源正確釋放

### Phase 3: 測試與優化 (0.5天)
1. **整合測試** - 驗證 timer + IPC 工作流程
2. **效能優化** - 調整更新頻率，避免過度 IPC 通信
3. **邊界條件測試** - 測試各種異常情況

## 詳細實作步驟

### 1. 修改 main.zig 核心邏輯
- 創建 CountdownTimer 實例
- 初始化 IPC 通信
- 實現主事件循環：
  - 檢查鍵盤輸入
  - 更新計時器狀態
  - 發送 IPC 更新消息
  - 檢查計時器結束條件

### 2. IPC 消息流程
```
啟動時: 無消息
運行中: 每秒發送 update_timer 消息
按鍵輸入: 處理 keyboard_input 消息
結束時: 發送 timer_finished 消息
退出: 發送 exit 消息
```

### 3. 錯誤處理策略
- IPC 通信失敗: 降級到純 CLI 模式（無 UI）
- 計時器錯誤: 立即終止程序
- 記憶體錯誤: 觸發 panic（遵循現有策略）

## 預期成果

1. **功能完整性**: 計時器能通過 IPC 與 UI 實時同步
2. **用戶體驗**: 支援鍵盤控制（暫停/繼續/退出）
3. **可靠性**: 完善的錯誤處理和資源管理
4. **可維護性**: 清晰的模組分離和通信協議

## 風險評估

- **低風險**: Timer 和 IPC 模組已完整實現
- **中風險**: IPC 通信可能因 Node.js 進程問題失敗
- **緩解方案**: 實現降級模式，通信失敗時仍能正常計時

## 測試策略

- **單元測試**: 驗證各模組整合後仍正常工作
- **整合測試**: 模擬完整工作流程
- **手動測試**: 實際運行計時器，驗證 UI 同步

## 實作日期

- **開始日期**: 2026-01-19
- **預計完成**: 2026-01-20 (Phase 1-2), 2026-01-21 (Phase 3)

---

**狀態**: 計劃通過，等待實作命令</content>
<parameter name="filePath">docs/integration-plan-timer-ipc-2026-01-19.md