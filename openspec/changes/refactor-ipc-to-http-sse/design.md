## Context

目前 tty-clock-timer 使用單向的 parent-child process 模型：
- **Core (Zig)** 作為 main process，spawn **TUI (OpenTUI/Bun)** 作為 child
- IPC 透過 stdio pipes：Core stdout → TUI stdin (JSON events)，TUI stdin 同時處理 TTY raw mode
- 這個設計導致 TUI 的 stdin 同時承載兩種職責：接收 IPC 訊息 + 處理鍵盤輸入

**限制：**
1. 無法支援多個 UI clients（只能 1-to-1）
2. TUI stdin 混雜 JSON parsing 與 raw TTY input
3. 難以擴展到其他 client 類型（IDE plugin, web dashboard）
4. Debugging 困難（需要 parse binary stdio）

**目標架構：**
採用 OpenCode 風格的 HTTP/SSE 架構：
- **Server (Bun)** 作為中心：管理 timer state，spawn Core process，廣播 events
- **Core (Zig)** 作為計算引擎：純粹處理高精度計時，透過 stdio 與 Server 通訊
- **Clients (TUI, etc.)** 作為觀察者：透過 HTTP/SSE 連接 Server

## Goals / Non-Goals

**Goals:**
- ✅ 分離關注點：TTY input 回歸 TUI，IPC 使用標準 HTTP/SSE
- ✅ 支援多 clients 同時連接並觀察同一個 timer
- ✅ 易於擴展新 client 類型（IDE plugin, CLI, web UI）
- ✅ 易於 debugging（HTTP inspector, curl 測試）
- ✅ 保持 Zig Core 的高精度計時能力

**Non-Goals:**
- ❌ 支援多個獨立 timer instances（此階段只有單一 shared timer）
- ❌ 認證/授權機制（localhost only，假設可信環境）
- ❌ 跨網路部署（只監聽 localhost）
- ❌ 改變 Zig Core 的計時邏輯（僅改通訊方式）

## Decisions

### Decision 1: Bun ↔ Zig 通訊使用 Child Process + stdio

**選擇：** Server 透過 `Bun.spawn()` 啟動 Zig Core，使用 stdio pipes 傳遞 JSON 訊息

**理由：**
- ✅ 最小改動：Zig Core 已有 stdio JSON IPC，幾乎無需修改
- ✅ Process 隔離：Core crash 不影響 Server
- ✅ 易於 debug：分別測試 Core 和 Server
- ✅ 避免 FFI 複雜度（memory management, ABI stability）

**替代方案：**
- ❌ FFI (shared library)：需處理跨語言 memory management，Zig master ABI 不穩定
- ❌ WASM：Zig → WASM 不成熟，且 WASM 缺乏高精度 timer API

### Decision 2: SSE (Server-Sent Events) 用於 Server → Clients 事件推送

**選擇：** 使用 SSE (`Content-Type: text/event-stream`) 推送 timer 更新

**理由：**
- ✅ 單向通訊已足夠（Server → Clients 推送事件）
- ✅ 基於 HTTP，無需 protocol upgrade（相比 WebSocket）
- ✅ 瀏覽器原生支援 `EventSource` API
- ✅ 自動重連機制
- ✅ Bun 原生支援（透過 `ReadableStream`）

**替代方案：**
- ❌ WebSocket：過於複雜（雙向通訊非必要），需額外 protocol upgrade
- ❌ Long polling：效率低，需手動處理重連

**實作：**
```typescript
// Server SSE endpoint
return new Response(
  new ReadableStream({
    start(controller) {
      timerEventBus.on("update", (data) => {
        controller.enqueue(`data: ${JSON.stringify(data)}\n\n`);
      });
    },
  }),
  { headers: { "Content-Type": "text/event-stream" } }
);
```

### Decision 3: REST API 用於 Clients → Server 命令

**選擇：** 提供 RESTful endpoints 處理控制命令

**API 設計：**
```
POST /start        body: { duration_seconds: number }
POST /pause
POST /resume
POST /reset
POST /stop
GET  /status       response: { remaining: number, status: string, ... }
GET  /events       (SSE endpoint)
```

**理由：**
- ✅ 標準 HTTP，易於測試（`curl`, Postman）
- ✅ 語意清晰（POST 用於 actions，GET 用於 queries）
- ✅ Stateless（每個請求獨立）

### Decision 4: Single Shared Timer（所有 clients 觀察同一個 timer）

**選擇：** Server 維護單一 timer instance，所有 clients 共享狀態

**理由：**
- ✅ 符合現有使用場景（單一使用者，多個視窗觀察同一個 timer）
- ✅ 簡化 Server 邏輯（無需 session management）
- ✅ 避免 race conditions（多個 timer 互相干擾）

**未來擴展：**
若需支援多 timer，可透過 session ID 或 URL path 區分：
```
POST /timers/:id/start
GET  /timers/:id/events
```

### Decision 5: Server 啟動流程採用 Manual Start

**選擇：** 使用者需手動啟動 Server，TUI 作為 client 連接

```bash
# Terminal 1: Start server
$ bun run server

# Terminal 2: Run TUI client
$ bun run tui
```

**理由：**
- ✅ 清晰的 process lifecycle（Server 獨立於 TUI）
- ✅ 支援多 clients（不同終端連接同一 server）
- ✅ 易於 debugging（分開運行、分開 log）

**替代方案（未來可加入）：**
- Daemon mode：`bun run server --daemon`（背景運行）
- Auto-start：TUI 檢測 server 未運行時自動啟動

## Risks / Trade-offs

### [風險] Latency 增加

**描述：** HTTP localhost round-trip 比 stdio pipe 慢（microseconds → milliseconds）

**緩解：**
- ✅ Timer 更新頻率 100ms，HTTP latency (~1ms) 影響極小
- ✅ SSE 是持久連接，無需每次重建 HTTP connection
- ✅ 若未來需要，可優化為 Unix domain socket

### [風險] Port 衝突

**描述：** 預設 port 8080 可能被佔用

**緩解：**
- ✅ 使用環境變數 `PORT` 允許自訂
- ✅ Server 啟動時檢測 port，若佔用則報錯並建議替代 port
- ✅ 預設改用較少見的 port（例：38080）

### [風險] EventSource 瀏覽器相容性

**描述：** TUI 運行在 Bun runtime，需確認 `EventSource` 支援

**緩解：**
- ✅ Bun 實作 Web APIs，應支援 EventSource（需驗證）
- ✅ 若不支援，可用 library（例：`eventsource-parser`）或手動實作 SSE client

### [權衡] 架構複雜度增加

**描述：** 從單一 binary 變成 Server + Core + Client 三層

**權衡：**
- ❌ 增加 deployment 複雜度（需啟動 Server）
- ❌ 增加 codebase size（新增 `server/` 目錄）
- ✅ 但換來可擴展性、可測試性、多 client 支援

### [權衡] Binary Size

**描述：** 若未來 Zig 改用 HTTP（而非 stdio），需引入 `std.http.Server`

**當前決策：**
- ✅ Zig 保持 stdio，不增加 binary size
- ✅ HTTP 層完全由 Bun 處理

## Migration Plan

### Phase 1: 建立新架構（平行運行）

1. **新增 `server/` 目錄**，實作 HTTP + SSE + process management
2. **新增 `tui-client/` 目錄**，實作 HTTP client 版本的 TUI
3. 保留現有 `core/` 和 `tui/` 不動（舊架構仍可運作）

### Phase 2: 測試與驗證

1. **Spike: Bun SSE**：驗證 multi-client broadcast
2. **Spike: Bun spawn Zig**：驗證 stdio communication
3. **Integration test**：Server + Core + TUI client 端到端測試

### Phase 3: 切換與清理

1. **重命名**：`tui/` → `tui-legacy/`，`tui-client/` → `tui/`
2. **更新文件**：CLAUDE.md, README.md
3. **移除** legacy code（若新架構穩定）

### Rollback Strategy

若新架構有問題：
- 保留 `tui-legacy/` 和舊版 `core/src/main.zig`
- 使用 git tag 標記重構前版本
- 可快速回退到 stdio 架構

## Open Questions

1. **EventSource 在 Bun runtime 的支援？**
   - 需實際測試 Bun 是否實作 `EventSource` API
   - 若否，評估 fallback library 或手動實作

2. **Server 的預設啟動行為？**
   - Manual start（需手動 `bun run server`）
   - Auto-start（TUI 自動啟動 server）
   - Daemon mode（背景持續運行）
   - → 先實作 manual，之後加入其他模式

3. **Error handling 策略？**
   - Server 死掉時，TUI 如何處理？（顯示錯誤 + 重連機制）
   - Core crash 時，Server 如何通知 clients？（broadcast error event）
   - → 需在 specs 詳細定義

4. **未來擴展：Per-client timers？**
   - 若要支援多個獨立 timer，API 設計需調整（`/timers/:id`）
   - Session management（每個 client 有獨立 timer instance）
   - → 當前不做，但設計預留擴展空間
