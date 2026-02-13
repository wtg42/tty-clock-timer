# tty-clock-timer TUI

`tui/` 是 OpenTUI（Solid）前端，負責顯示倒數狀態、接收鍵盤操作，並經由 Unix Socket 與 Zig Core 通訊。

## 開發指令

```bash
bun install
bun run dev
```

## 目前行為

- 支援按鍵：`p`（pause）、`r`（resume）、`s`（reset）、`q`（quit）。
- 透過 in-process Hono command plane 處理命令，再交給 Unix socket adapter 發送到 Core。
- 接收 Core 事件：`update_timer`、`timer_finished`、`exit`，並同步到 Store 後渲染畫面。
- Socket path 可用 `--socket-path <path>` 指定，預設 `/tmp/tty-clock-timer.sock`。

## 主要檔案

- `src/index.tsx`：UI entry、socket 連線、鍵盤事件與 render。
- `src/command_plane.ts`：Hono command plane（命令路由與回應）。
- `src/unix_socket_adapter.ts`：Unix Socket 讀寫與命令傳送。
- `src/store.ts`：Timer projection state（由事件驅動更新）。
- `src/protocol.ts`：command/event 型別與解析。
