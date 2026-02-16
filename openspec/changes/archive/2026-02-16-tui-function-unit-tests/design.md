## Context

目前 `tui/` 以 TypeScript + OpenTUI 開發，但缺少可自動執行的函式層級測試，導致邏輯正確性主要依賴手動執行與整體 UI 驗證。此次變更需要在不引入 feature tests（例如整體互動流程、跨模組整合）的前提下，建立最小可行且可持續擴充的單元測試結構。

主要限制如下：
- 現有 `tui/` 尚未提供既有測試腳本與測試框架約定。
- 測試目標限定為 function-level，不測試終端渲染流程或 IPC 全鏈路。
- 需維持 `strict` TypeScript 型別約束，避免測試程式碼弱化型別品質。

## Goals / Non-Goals

**Goals:**
- 在 `tui/` 建立標準化 unit test 執行方式（腳本、目錄與命名慣例）。
- 讓純函式（格式化、轉換、狀態計算等）可被隔離測試。
- 為高風險邏輯補齊正常路徑與邊界/錯誤路徑測試案例。

**Non-Goals:**
- 不新增 feature tests、E2E tests 或 UI snapshot tests。
- 不驗證 OpenTUI 元件渲染結果或鍵盤互動流程。
- 不改變產品功能需求與 CLI/TUI 對外行為。

## Decisions

### 1) 採用以函式邏輯為中心的測試分層
- Decision: 將可測邏輯抽離至獨立模組（或保持既有純函式），測試僅呼叫函式輸入/輸出。
- Rationale: 降低測試對 runtime/terminal 環境依賴，提升穩定度與執行速度。
- Alternatives considered:
  - 直接測元件行為：會混入 rendering 與框架細節，偏離 function-level 範圍。
  - 以整體流程測試取代單元測試：回饋慢且定位問題成本高。

### 2) 建立明確測試邊界與命名慣例
- Decision: 測試檔案與目標函式對齊，案例命名採「函式/情境」格式，明確區分正常與例外路徑。
- Rationale: 增加可讀性並使維護者可快速定位回歸來源。
- Alternatives considered:
  - 自由命名：短期彈性高，但長期一致性與可搜尋性較差。

### 3) 以最小侵入方式導入測試工具鏈
- Decision: 僅新增 unit test 所需依賴與 script，不額外引入與本次範圍無關的驗證層。
- Rationale: 控制導入成本，避免將 feature-test 複雜度帶入本次變更。
- Alternatives considered:
  - 一次導入完整測試金字塔：超出本次需求，且會拉長導入與維護成本。

## Risks / Trade-offs

- [Risk] 函式尚未純化，測試撰寫時需先重構邏輯邊界 → Mitigation: 只做必要抽離，避免大規模重寫。
- [Risk] 測試覆蓋率聚焦函式層，無法捕捉整合問題 → Mitigation: 在文件中明確聲明範圍，後續以獨立 change 補 feature tests。
- [Risk] 工具鏈設定不足造成本機與 CI 行為不一致 → Mitigation: 統一 script 與執行入口，使用相同命令驗證。

## Migration Plan

1. 新增 `tui/` 單元測試執行腳本與必要依賴。
2. 盤點並標記可做 function-level 測試的核心函式。
3. 補齊首批函式測試案例（正常/邊界/錯誤）。
4. 在變更說明中標註「不含 feature tests」，避免範圍誤解。
5. 以單一測試命令驗證可重複執行，供本機與 CI 共用。

回滾策略：若導入失敗，移除新增測試設定與腳本，不影響既有 runtime 行為。

## Open Questions

- `tui/` 目前最合適的測試執行器（以既有工具鏈相容性與啟動速度為優先）需在實作前最終確認。
- 首批必測函式清單需依現有模組結構盤點後定稿。
