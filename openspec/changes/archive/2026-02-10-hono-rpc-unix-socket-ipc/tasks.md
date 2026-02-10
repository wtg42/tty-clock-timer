## 1. Command Plane（Hono in-process）

- [x] 1.1 在 `tui` 新增 Hono 依賴與 command boundary 模組骨架（路由、請求/回應型別）。
- [x] 1.2 定義 MVP 命令 `pause`、`resume`、`reset`、`quit` 的統一回應格式（成功/失敗）。
- [x] 1.3 讓 OpenTUI action 改以 in-process fetch/RPC 呼叫 Hono command endpoint。

## 2. Core-Node Unix Socket IPC

- [x] 2.1 在 Zig Core 建立 Unix Domain Socket server/client（依既有程序角色）並完成啟動/關閉流程。
- [x] 2.2 在 Node 端建立對應 Unix socket adapter，實作 command 發送與事件接收。
- [x] 2.3 加入 socket path 初始化與 stale socket 清理策略，並輸出可診斷錯誤訊息。

## 3. Event Plane 與 UI 投影狀態

- [x] 3.1 建立 Node Store/EventBus，將 Core 事件轉為可渲染狀態。
- [x] 3.2 將 OpenTUI 倒數顯示來源改為 Store 投影狀態（非直接解析 transport 細節）。
- [x] 3.3 驗證命令觸發後（pause/resume/reset）UI 狀態可透過事件回流正確更新。

## 4. 驗證與收斂

- [x] 4.1 驗證既有行為：倒數顯示與 `quit` 流程在新通道下仍符合需求。
- [x] 4.2 執行 `core` 端測試與建置檢查（至少 `zig build test`、`zig build`）。
- [x] 4.3 更新必要文件（IPC/模組邊界）並移除或降級舊 stdio 控制通道依賴。
