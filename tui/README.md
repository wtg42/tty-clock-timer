# tty-clock-timer TUI

`tui/` 是 OpenTUI（Solid）前端，負責顯示倒數狀態、接收鍵盤操作，並經由 Unix Socket 與 Zig Core 通訊。

## 開發指令

```bash
bun install
bun run dev
bun test
```

- `bun run dev`：以 watch 模式執行 `src/index.tsx`。
- `bun test`：執行 `src/**/*.test.ts` 的單元測試。
- 目前 `tui/` 尚未提供獨立 lint/type-check script（`tsconfig.json` 設為 `noEmit`）。

## TUI 端到端資料流（聚焦 `src/` 檔案職責）

```text
Keyboard (p/r/s/q)
        |
        v
+-------------------+        uses         +------------------+
| src/index.tsx     | ------------------> | src/ui_logic.ts  |
| App + lifecycle   |                     | key/skip/dedup   |
+---------+---------+                     +------------------+
          |
          | issue command
          v
+-----------------------+   normalize   +---------------------------+
| src/command_plane.ts  | ------------> | CommandResponse (contract)|
+---------+-------------+               +---------------------------+
          |
          | send command JSON over unix socket
          v
+---------------------------+     IPC      +----------------------+
| src/unix_socket_adapter.ts| <----------> | Zig Core (core/)     |
| transport + correlation   |              | timer + command exec |
+---------+-----------------+              +----------+-----------+
          ^                                           |
          | CoreEvent JSON lines                      | emits events:
          |                                           | update_timer /
          |                                           | timer_finished / exit
          +-----------------------------+-------------+
                                        |
                                        v
                              +-------------------+
                              | src/protocol.ts   |
                              | runtime guards    |
                              +---------+---------+
                                        |
                                        v
                              +-------------------+
                              | src/store.ts      |
                              | event projection  |
                              +---------+---------+
                                        |
                                        v
                              +-------------------+
                              | src/index.tsx     |
                              | render UI state   |
                              +-------------------+
```

## 模組職責（`src/`）

- `src/index.tsx`：TUI composition root。組裝 adapter/store/command plane、處理 keyboard 與連線生命週期，最後 render。
- `src/ui_logic.ts`：純函式決策層（時間格式化、按鍵轉命令、狀態檢查、短時間 dedup）。
- `src/command_plane.ts`：in-process command boundary。統一 `POST /commands/:command` 進入點與 `CommandResponse` 正規化。
- `src/unix_socket_adapter.ts`：transport layer。處理 Unix socket 連線、line-delimited JSON framing、command request/response 對應。
- `src/protocol.ts`：資料契約邊界。定義 command/event type，並提供 runtime guards（`isCoreEvent`、`isCommandResultMessage`）。
- `src/store.ts`：事件投影層。將 `CoreEvent` 投影為 `TimerViewState`，以 subscribe API 驅動畫面更新。

## 資料契約（Protocol）

- TUI 與 Core 的資料交換以 JSON message 為基礎。
- inbound event：`update_timer`、`timer_finished`、`exit`。
- outbound command：`pause`、`resume`、`reset`、`quit`。
- `src/protocol.ts` 是唯一型別與 runtime 驗證入口，避免未驗證 payload 直接影響 UI 狀態。

## 目前行為

- 支援按鍵：`p`（pause）、`r`（resume）、`s`（reset）、`q`（quit）。
- 命令路徑：`index.tsx` -> `command_plane.ts` -> `unix_socket_adapter.ts` -> Core。
- 事件回流：Core -> `unix_socket_adapter.ts` -> `protocol.ts` guard -> `store.ts` -> `index.tsx` render。
- Socket path 可用 `--socket-path <path>` 指定，預設 `/tmp/tty-clock-timer.sock`。

## Unit test 範圍（目前）

- 僅包含 function-level unit tests。
- 測試檔案與目標函式同目錄，採 `*.test.ts` 命名（例如 `store.test.ts`）。
- 測試案例命名採「`函式/情境`」風格，方便定位失敗案例。
- 目前**不包含** feature tests（跨模組流程、整體 UI 互動、E2E）。

### 測試對映

- `ui_logic.ts`: `formatRemaining`、`commandFromKey`、`shouldSkipByStatus`、`shouldSkipByDedup`
- `protocol.ts`: `isCoreEvent`、`isCommandResultMessage`
- `store.ts`: `createTimerStore` 的 event projection 行為
