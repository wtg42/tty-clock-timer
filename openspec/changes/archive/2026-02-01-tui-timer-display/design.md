## Context

目前 OpenTUI 未顯示倒數時間與狀態，timer 資訊主要透過 IPC 傳遞但未在 UI 呈現。此變更需在不改動 core 計時邏輯前提下，讓 UI 讀取既有 timer 更新訊息並顯示。

## Goals / Non-Goals

**Goals:**
- 在 OpenTUI 畫面顯示剩餘時間與狀態
- 透過既有 IPC timer 更新訊息驅動 UI

**Non-Goals:**
- 不修改 timer 核心邏輯或狀態機
- 不調整 IPC 協定格式

## Decisions

- 以既有 IPC 更新訊息作為單一資料來源，避免重複計算時間
- UI 僅負責顯示與格式化，不處理計時狀態推進

## Risks / Trade-offs

- UI 更新頻率受 IPC 推送節奏影響 → 維持與 core 相同的更新間隔，避免不同步
