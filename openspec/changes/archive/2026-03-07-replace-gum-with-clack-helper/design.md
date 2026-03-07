## Context

目前 Zig core 透過 spawn `gum` binary 處理三類互動流程：history 單選、history 多選刪除、`--setup-sound`。這條路徑讓專案需要額外維護 `gum` 下載腳本、checksum、AppImage runtime artifact 與對應 verify 規則；同時只有 `list` 保留純 Zig fallback，其餘互動流程已經高度依賴外部工具。

專案另一側已經建立 Bun-based runtime 與 build 流程：TUI 由 `tui/build.ts` 產生 bundle，core 再以 `bun run` 啟動。這代表專案已接受「UI 相關互動可依賴 Bun runtime」的基本方向。此次變更將 CLI prompt 互動也納入同一個依賴模型，並把 `gum` 從版本控制與 AppImage 打包路徑中移除。

## Goals / Non-Goals

**Goals:**
- 用獨立的 Bun + Clack helper 取代 `gum`，移除 `gum` binary 與下載/校驗流程。
- 讓 Zig core 與 helper 以 JSON 契約交換結果，降低字串解析與 exit code 猜測。
- 將 helper artifact 放在 `tui/dist/prompts/helper.js`，與 TUI bundle 同層打包但保持責任分離。
- 簡化架構，取消純 Zig fallback，將 prompt flow 正式視為 Bun runtime 的一部分。

**Non-Goals:**
- 不在此次變更中移除 TUI 對 host `bun` 的 runtime 需求。
- 不把 prompt helper 併入 OpenTUI 主 bundle 或 IPC command plane。
- 不重新設計 history、sound config 或 timer 的資料模型。

## Decisions

### 1. Prompt helper 以獨立 bundle 存放於 TUI runtime root 內
- 決定：新增獨立的 prompt helper bundle，預設路徑為 `tui/dist/prompts/helper.js`，AppImage 內對應 `usr/lib/tty-clock-timer/tui/prompts/helper.js`。
- 原因：helper 與 OpenTUI 主畫面屬於不同責任；分開 artifact 能避免把 Clack 依賴混進 TUI 主 entry，也讓 Zig core 更容易把 helper 當成可替換 command 處理。
- 替代方案：
  - 併入 `index.js`：會讓 prompt 與 TUI runtime 強耦合，不利於獨立呼叫。
  - 直接保留 TypeScript 腳本並 `bun run` 原始碼：開發期可行，但 release artifact 與 AppImage 路徑管理較鬆散。

### 2. Zig core 與 helper 透過子命令 + JSON 單次回應溝通
- 決定：core 以 `bun run prompts/helper.js -- <subcommand> ...` 呼叫 helper；helper 針對 `history-select`、`history-delete`、`setup-sound` 三種流程輸出單一 JSON 物件到 stdout。
- 原因：JSON 比目前依賴 stdout 純文字與 exit code 更可擴充，也更容易區分成功、取消與錯誤。
- 契約方向：
  - 成功：`{"status":"submitted", ...}`
  - 取消：`{"status":"canceled"}`
  - 預期錯誤：`{"status":"error","code":"..."}` 並以非零退出
- 替代方案：
  - 延續純文字輸出：需要維持多種分支解析與隱含語義。
  - 只靠 exit code：很難表達多選結果與欄位化資料。

### 3. Prompt flow 不再保留純 Zig fallback
- 決定：移除 `list` 的純文字 fallback，將 `list`、`list --delete`、`--setup-sound` 全部統一到 prompt helper。
- 原因：目前 fallback 只覆蓋部分流程，持續維護兩套路徑的成本高於收益；使用者已接受 Bun runtime 是互動層的一部分時，統一執行模型更直接。
- 替代方案：保留 fallback 作為 no-bun 或 no-TTY 後備；缺點是再次引入雙路徑邏輯與測試負擔。

### 4. 移除 gum 專屬 packaging 供應鏈，改驗證 helper artifact
- 決定：刪除 `fetch-gum.sh`、gum checksum/bundle/verify 規則，改為在 build 與 AppImage verify 中檢查 `prompts/helper.js` artifact 存在。
- 原因：此次變更的主要價值就是消除額外 native tool 鏈，將 CLI prompt 完整收斂到既有 Bun build 產物。
- 替代方案：保留 gum 作為 fallback/備援工具；缺點是無法真正減少版本控制與打包複雜度。

## Risks / Trade-offs

- [Prompt flow 更依賴 Bun runtime] → 以明確錯誤訊息與單一路徑契約處理，避免隱性 fallback 造成行為不一致。
- [Helper 與 TUI build 共用 dist root，artifact 邊界可能混亂] → 將 helper 固定放在 `dist/prompts/`，並在 spec 與 packaging contract 中明確命名。
- [JSON 契約若設計不穩定，Zig/JS 兩側容易脫鉤] → 以固定 `status` 欄位與每個子命令專屬 payload 定義最小協議，避免自由型輸出。
- [移除 gum 後既有文件與驗證腳本可能殘留舊假設] → 本次 change 一併修改 AppImage 打包/驗證規格與相關說明。

## Migration Plan

1. 在 `tui/` 建立 prompt helper entry 與對應 build 產物位置。
2. 在 core 內以 helper spawn 取代 `gum` 呼叫與 fallback 流程。
3. 更新 packaging 與 verify，改驗證 helper bundle，移除 `gum` artifact。
4. 更新文件與 OpenSpec specs，讓「prompt flow 依賴 Bun」成為正式契約。

## Open Questions

- 目前不保留待決問題；本 change 已決定 helper 使用獨立 bundle、JSON 契約、無純 Zig fallback。
