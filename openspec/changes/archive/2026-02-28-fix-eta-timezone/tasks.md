## 1. Core IPC 協定修改（Zig）

- [x] 1.1 修改 `core/src/lib/ipc.zig`：將 `UpdateTimerPayload` 的 `eta_hhmm: []const u8` 欄位改為 `eta_epoch_seconds: u64`
- [x] 1.2 更新 `ipc.zig` 序列化邏輯：將 `eta_hhmm` JSON 欄位名稱與寫入改為 `eta_epoch_seconds`（數值型別）
- [x] 1.3 更新 `ipc.zig` 反序列化邏輯：移除字串解析，改為數值解析
- [x] 1.4 更新 `ipc.zig` 記憶體釋放邏輯：移除 `allocator.free(payload.eta_hhmm)`（數值不需釋放）

## 2. Core 主邏輯修改（Zig）

- [x] 2.1 修改 `core/src/main.zig`：移除 `formatEtaHhmm` 函式及 `eta_buffer` 變數
- [x] 2.2 修改 `sendTimerUpdate`：直接傳入 `eta_epoch_seconds`（raw u64）取代格式化字串
- [x] 2.3 更新 `ipc.updateTimer` 呼叫點：移除 `eta_hhmm` 參數，改傳 `eta_epoch_seconds`

## 3. Core 測試更新（Zig）

- [x] 3.1 更新 `ipc.zig` 測試：移除 `eta_hhmm` 欄位斷言，改為 `eta_epoch_seconds` 數值斷言
- [x] 3.2 執行 `zig build test` 確認所有 core 測試通過

## 4. TUI 協定型別更新（TypeScript）

- [x] 4.1 修改 `tui/src/protocol.ts`：將 `UpdateTimerPayload` 的 `eta_hhmm: string` 改為 `eta_epoch_seconds: number`
- [x] 4.2 更新 `isUpdateTimerPayload` 型別守衛：改為驗證 `eta_epoch_seconds` 為 `number`

## 5. TUI 顯示邏輯更新（TypeScript）

- [x] 5.1 修改 `tui/src/store.ts`：新增本地時間格式化函式，將 `eta_epoch_seconds * 1000` 轉為 `HH:MM`（使用 `toLocaleTimeString` with `{ hour: '2-digit', minute: '2-digit', hour12: false }`）
- [x] 5.2 修改 `tui/src/index.tsx`（或相關元件）：使用新的本地時間格式化取代直接顯示 `eta_hhmm`

## 6. TUI 測試更新（TypeScript）

- [x] 6.1 更新 `tui/src/protocol.test.ts`：移除 `eta_hhmm` 相關測試，新增 `eta_epoch_seconds` 驗證
- [x] 6.2 更新 `tui/src/store.test.ts`：更新涉及 ETA 的測試案例
- [x] 6.3 執行 `bun test` 確認所有 TUI 測試通過
