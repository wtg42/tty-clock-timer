## Context

目前 CLI 與 OpenTUI 分開啟動，使用者需手動開啟 UI 才能看到倒數資訊。核心程序已具備 IPC 輸出 timer 更新訊息，但 UI 進程尚未由 CLI 直接啟動。

## Goals / Non-Goals

**Goals:**
- CLI 啟動時自動啟動 OpenTUI UI 進程
- UI 進程與 CLI 透過既有 IPC 管道接收 timer 更新訊息

**Non-Goals:**
- 不修改計時器核心邏輯與狀態機
- 不改變 IPC 訊息格式
- 不設計 UI 端的時間設定流程

## Decisions

- 由 CLI 主程序負責啟動 OpenTUI 子進程，確保生命周期與 timer 同步
- IPC 仍使用 stdout/stderr 或既有管道，避免引入新依賴

## Risks / Trade-offs

- 子進程啟動失敗會影響 CLI 體驗 → 需提供清楚的錯誤訊息與 fallback 行為
- UI 進程與 CLI 綁定 → 需處理 CLI 結束時的 UI 清理
