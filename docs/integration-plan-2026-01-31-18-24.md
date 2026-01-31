# 整合計劃書 - Timer IPC 實作架構

## 專案背景

tty-clock-timer 目前已具備 CLI 參數解析、Timer 核心邏輯與 IPC 通信模組。本計劃書定義 Timer 與 IPC 的整合實作架構，聚焦在 `core/src/main.zig` 入口層的主流程接線。

## 目標範圍

- 將 `core/src/main.zig` 整合 Timer + IPC + 鍵盤輸入
- IPC 訊息流：`update_timer`、`timer_finished`、`exit`
- 鍵盤事件：先支援 `q` 退出
- 初始化失敗直接結束並回應錯誤訊息

## 架構分層

- **核心層（core/src/lib）**：`timer.zig`、`ipc.zig`、`allocator.zig` 維持既有 API
- **入口層（core/src/main.zig）**：負責初始化、主事件循環、錯誤處理、資源釋放
- **UI 層（tui/src/index.tsx）**：消費 IPC 訊息並呈現狀態（若需擴充再調整）

## 核心決策

- 初始化失敗：直接輸出錯誤並結束程式
- IPC 節流：採固定每秒更新（最簡單實作）
- 鍵盤事件：先支援 `q`，其餘後續擴充

## 實作階段

### Phase 1: 初始化與主流程

1. 在 `core/src/main.zig` 解析 CLI 參數並建立 Timer
2. 初始化 IPC 通信
3. 任一步驟失敗：立即輸出錯誤並結束
4. 建立主事件循環（1 秒 tick）

### Phase 2: 狀態同步與事件處理

1. 每秒更新 Timer 並送出 `update_timer`
2. 監聽鍵盤輸入：`q` 觸發退出流程
3. Timer 完成：送出 `timer_finished` 並結束
4. 退出流程：送出 `exit` 並結束

### Phase 3: 資源管理與錯誤處理

1. `defer` 釋放 IPC、Timer、Allocator
2. 任何初始化錯誤直接退出
3. IPC 傳輸錯誤以簡單策略處理（出錯即結束）

## IPC 訊息流程

```
啟動: 無消息
運行中: 每秒發送 update_timer
結束: 發送 timer_finished
退出: 發送 exit
```

## 測試策略

- `zig fmt core/src/*.zig core/src/lib/*.zig`
- 建議執行 `zig build test`

## 狀態

- 已確認實作方向，等待開始實作
