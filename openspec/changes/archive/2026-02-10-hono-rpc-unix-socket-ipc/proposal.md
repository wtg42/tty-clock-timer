## Why

目前 `core` 與 `tui` 之間的通訊主要是單向 stdin/stdout JSON line，適合早期驗證，但在擴展 UI command、跨專案複用架構與邊界測試時，耦合點過高且不易重用。現在導入 in-process Hono RPC + Unix Domain Socket，可建立可複製的 CLI 應用骨架（Command Plane 與 Event Plane 分離），降低後續新專案重工成本。

## What Changes

- 新增 Node 進程內的 Hono command boundary，讓 OpenTUI 以 in-process RPC/fetch 觸發 command。
- 新增 Zig Core 與 Node 之間的 Unix Domain Socket IPC，取代目前以子程序 stdio 為主的控制通道。
- 建立 Node 端 Store/EventBus 投影層：接收 Core 事件、同步 UI render 所需狀態。
- 將 UI 互動（至少 pause/resume/reset/quit）統一走 command plane，不直接耦合 transport 細節。
- 保持既有倒數顯示與退出行為，優先以 MVP 可落地為目標，不引入 SSE、Worker、多 client。

## Capabilities

### New Capabilities
- `hono-command-plane`: 定義 OpenTUI 透過 in-process Hono RPC 發送 command 並獲得一致回應語意。
- `unix-socket-ipc-bridge`: 定義 Zig Core 與 Node 以 Unix Domain Socket 進行雙向 command/event 傳遞。

### Modified Capabilities
- `tui-timer-display`: 更新「UI 狀態來源」為 Node Store/EventBus 投影層（由 Core 事件驅動），維持倒數顯示需求。

## Impact

- Affected code：`core/src/main.zig`、`core/src/lib/ipc.zig`、`tui/src/index.tsx`，以及新增 Node 端 command/store/adapter 模組。
- API/Protocol：新增 command/event 合約（含最小命令集合與錯誤回應格式）。
- Runtime：新增 Unix Domain Socket 生命週期管理（socket path、清理、斷線處理）。
- Dependencies：`tui` 需新增 Hono 相關依賴。
