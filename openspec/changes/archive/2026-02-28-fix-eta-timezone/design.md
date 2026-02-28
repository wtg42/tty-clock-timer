## Context

目前 Core（Zig）在送出 `update_timer` IPC 訊息前，會將 ETA epoch seconds 格式化為 `HH:MM` 字串（`eta_hhmm`），格式化時使用 `std.time.epoch.EpochSeconds.getDaySeconds()`，此 API 回傳的是 **UTC** 當日秒數，未套用任何時區偏移。非 UTC 時區的使用者（如 UTC+8 台灣）會看到錯誤的 ETA。

## Goals / Non-Goals

**Goals:**
- ETA 在所有時區均顯示正確的本地時間
- IPC 協定改傳語意明確的數值（epoch seconds），由 TUI 端決定如何呈現
- 移除 Core 端與顯示格式相關的邏輯，使 Core 只負責計時語意

**Non-Goals:**
- 不改變 ETA 的凍結/解凍計算邏輯
- 不支援使用者自訂時區或時間格式
- 不修改 socket IPC（行為一致）

## Decisions

### 決策 1：ETA 格式轉移至 TUI 端

**選項 A（採用）**：Core 傳 `eta_epoch_seconds: number`，TUI 用 `new Date(epoch * 1000).toLocaleTimeString('zh-TW', { hour: '2-digit', minute: '2-digit', hour12: false })` 格式化。

**選項 B**：Core 讀取 `$TZ` 或解析 `/etc/localtime` 自行計算 offset。

選擇 A 的理由：
- Zig std 無跨平台的 local timezone API，自行解析複雜且易出錯（DST、特殊時區）
- JavaScript `Date` 物件天然使用系統本地時間，零邊界情況
- 遵循「Core 只管計時邏輯，TUI 負責呈現」的架構分工

### 決策 2：欄位重命名而非新增

移除 `eta_hhmm` 欄位，以 `eta_epoch_seconds` 取代，不做向後相容過渡。理由：Core 與 TUI 始終一起部署，不存在跨版本相容需求。

## Risks / Trade-offs

- [風險] `toLocaleTimeString` 格式因 OS/locale 設定不同可能略有差異 → 緩解：明確指定選項 `{ hour: '2-digit', minute: '2-digit', hour12: false }` 確保輸出為 `HH:MM`
- [風險] 測試中的硬編碼 `eta_hhmm` 字串需全面更新 → 緩解：搜尋並更新所有相關測試
