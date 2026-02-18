## Context

現行 `tty_clock_timer` 主要輸入模式為 `--minutes` / `--seconds`，沒有歷史回用能力。使用者需求為引入 `list` 子命令並支援快速互動選單；同時因 OpenTUI 對一次性選擇流程偏重，希望透過 `gum` 作為輕量互動工具，但不讓系統硬依賴外部安裝。

## Goals / Non-Goals

**Goals:**
- 提供可重複使用的歷史時長清單，降低重複輸入成本
- 透過 `list` 子命令完成「選擇即執行」流程
- 在有 `gum` 時提供較佳互動體驗，無 `gum` 時仍可用
- 歷史檔案遵循 XDG 規範儲存於 state 路徑

**Non-Goals:**
- 不將歷史選單整合進 OpenTUI 主倒數畫面
- 不引入資料庫或複雜同步機制
- 不在本變更處理跨裝置同步

## Decisions

### Decision 1: `list` 是 core CLI 一次性流程

`list` 由 core 直接處理，完成後返回既有 timer 執行流程。OpenTUI 保持在倒數顯示與控制命令責任，不擴張至歷史選單。

**替代方案**：
- 在 OpenTUI 新增歷史選單頁：互動完整但啟動成本高、責任混雜

### Decision 2: history 儲存採 XDG state 路徑

優先使用 `$XDG_STATE_HOME/tty-clock-timer/history.json`，fallback `~/.local/state/tty-clock-timer/history.json`。若目錄不存在則自動建立。

**理由**：history 屬執行期 state，不是使用者靜態設定。

### Decision 3: `gum` 為 optional integration

執行順序：
1. 專案內建 binary（`tools/gum/<platform>/gum`）
2. 系統 PATH 的 `gum`
3. 內建純文字 fallback 選單

`gum` 執行失敗或超時必須 fallback，不得中斷 `list` 主流程。

### Decision 4: history 管理策略

- 以 duration seconds 作為主鍵進行去重
- 依最近使用時間排序（最新優先）
- 設定可配置或固定上限（例如 50 筆）
- JSON 損壞時不崩潰：記錄告警並以空清單啟動

## Risks / Trade-offs

- **[外部 binary 相依]**：bundled gum 與平台架構管理增加發版負擔 → 以 optional + fallback 降風險
- **[歷史檔損壞]**：使用者手動編輯可能造成 parse 失敗 → 採寬容讀取與自動重建
- **[行為一致性]**：gum 與 fallback 選單互動細節不同 → 規範共同最小語意（可選、可取消、可重試）

## Migration Plan

1. 新增 history module 與資料結構
2. 擴充 CLI 解析支援 `list`
3. 實作 gum lookup + fallback 選單
4. 接上「選擇即啟動」與 history 寫入流程
5. 補齊 unit tests 與整合驗證

## Open Questions

- history 最大筆數應固定（例如 50）或可由設定覆寫？
- `list` 取消時的 exit code 是否定義為 0（使用者主動取消）？
