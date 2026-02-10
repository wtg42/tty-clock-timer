## Context

目前 `tty-clock-timer` 採用 Zig Core + OpenTUI 子進程架構，計時狀態從 Core 以 stdio JSON line 推送到 UI。此模式在單向顯示場景可行，但當 UI 需要穩定地發送 command（pause/resume/reset/quit）回 Core 時，會與 foreground TTY I/O 的責任界線混雜，降低可維護性與跨專案複用性。

本次變更目標是建立可複製的 CLI 應用骨架：
- Command Plane：UI action 經由 in-process Hono RPC 進入 command boundary。
- Event Plane：Core 狀態變化回流至 Node Store/EventBus，再驅動 UI render。

此設計優先支援 MVP，避免引入 SSE、Worker、多 client 等延伸能力。

## Goals / Non-Goals

**Goals:**
- 建立「UI -> Hono RPC -> Core」的一致 command 邊界。
- 建立「Core -> Node projection -> UI」的事件驅動顯示管線。
- 以 Unix Domain Socket 作為 Core 與 Node 的雙向 transport，避免 TTY stdio 互相干擾。
- 保持 Zig Core 為單一 source of truth；Node Store 僅為 projection/cache。
- 形成可套用到其他 CLI app 的通用心智圖與模組邊界。

**Non-Goals:**
- 不引入網路化 API（不開對外 HTTP port）。
- 不在 MVP 階段支援 SSE、Worker、多 UI client。
- 不改變核心 timer domain 規則（倒數計時邏輯保持既有語意）。

## Decisions

### Decision 1: 使用 in-process Hono 作為 command boundary
- 決策：OpenTUI action 透過 in-process `fetch/RPC` 呼叫 Hono handler，再由 adapter 轉發至 Core。
- 原因：
  - 可保留 HTTP-like contract（method/path/payload/error）作為跨專案可複用介面。
  - 在同進程內避免額外網路部署與 port 管理負擔。
- 替代方案：
  - 直接函式呼叫（耦合高，難以抽換 transport）。
  - 開本機 HTTP server（可行但超出 MVP 複雜度）。

### Decision 2: Core <-> Node transport 使用 Unix Domain Socket
- 決策：以 Linux Unix socket 作為雙向 IPC 主通道。
- 原因：
  - 與 OpenTUI foreground TTY I/O 解耦，避免 stdin/stdout 衝突。
  - 相較 TCP 更輕量且符合本專案 Linux-only 假設。
- 替代方案：
  - 持續使用 stdio（易與 UI 畫面輸出競爭）。
  - TCP localhost（可攜性高，但 MVP 增加額外面向）。

### Decision 3: 採用雙平面模型（Command Plane / Event Plane）
- 決策：command 與 event 分離，不用同一條 request-response 管線承載狀態推送。
- 原因：
  - timer 狀態更新是持續事件，不適合以 polling command 查詢取代。
  - 讓 UI action 的語意（請求）與狀態渲染語意（訂閱）清晰分層。
- 替代方案：
  - UI 全部以輪詢 query 取得狀態（延遲高且語意不自然）。

### Decision 4: Node 端維持 Store/EventBus，且只做 projection
- 決策：Node 保存可渲染狀態快取，來源僅來自 Core 事件；不得自行推導核心真相。
- 原因：
  - 避免雙狀態機造成分歧。
  - 讓 OpenTUI 可用簡單 subscribe 模型更新畫面。
- 替代方案：
  - UI 直接消費原始 transport 訊息（可行但複用性與可測試性較差）。

### Decision 5: MVP 命令面只涵蓋最小集合
- 決策：MVP 僅要求 `pause`、`resume`、`reset`、`quit` command contract。
- 原因：
  - 先驗證架構骨幹，避免需求膨脹。
  - 後續命令可在同一 contract 模式擴展。

## Risks / Trade-offs

- [Risk] Socket 斷線或殘留檔案導致連線失敗 → Mitigation：定義啟動時 stale socket 清理與失敗訊息。
- [Risk] Node projection 狀態落後於 Core → Mitigation：事件處理採單線序列化，必要時提供一次性狀態同步命令。
- [Risk] 引入 Hono 增加模組數量與學習成本 → Mitigation：限制 Hono 僅作 boundary，不承載 domain 決策。
- [Risk] MVP 命令集過小，後續需求插入時需調整接口 → Mitigation：命令 payload 先採可擴展結構，保留版本欄位空間。

## Migration Plan

1. 先建立 Node 端 command boundary 與 store/event bus 骨架，不改 timer domain 行為。
2. 新增 Unix socket transport，讓 Core 與 Node 可雙向交換 command/event。
3. 將 OpenTUI action 改由 Hono command 呼叫，顯示來源改為 store projection。
4. 驗證既有倒數顯示與 q 退出體驗仍符合需求。
5. 移除或降級舊 stdio 控制通道依賴（保留必要相容邏輯至完成驗證）。

## Open Questions

- MVP 是否需要顯式 command ack code（例如 `ok`/`rejected`/`invalid-state`）供 UI 呈現差異？
- Socket path 命名策略是否需支援多執行個體隔離（例如 PID/UUID）？
- Headless 模式（無 UI）是否在本 change 內維持相同行為，或列為後續 change？
