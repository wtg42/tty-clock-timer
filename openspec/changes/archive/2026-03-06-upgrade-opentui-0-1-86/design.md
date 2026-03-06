## Context

目前 TUI 以 Bun + OpenTUI/Solid 建置，核心互動路徑包含鍵盤事件、renderer teardown、native `.so/.dylib` 載入 shim 與 Unix socket IPC。`0.1.85`、`0.1.86` 的上游變更集中在 terminal mode restore、mouse mode 旗標處理、palette noisy terminal 容錯與 continuation cell 修正，屬於執行期互動穩定性範疇。此變更雖非架構重寫，但會跨越依賴管理、建置產物與終端行為驗證三個面向，需先定義一致的驗證策略再進入實作。

## Goals / Non-Goals

**Goals:**
- 將 `@opentui/core` 與 `@opentui/solid` 一次同步升級到 `0.1.86`，避免版本分裂。
- 保持 `tui/build.ts` 既有 bundle + native library 契約不變，確保產物仍可獨立執行。
- 將升級驗證從「可安裝/可建置/可測試」擴充為「終端互動可回歸驗證」。
- 明確定義 rollback 策略，若升級後出現 terminal regression 可快速回復。

**Non-Goals:**
- 不導入新的 UI 功能或重構既有 UI state 管理。
- 不變更 core 與 TUI IPC protocol 欄位定義。
- 不替換 Bun、Solid 或 build pipeline 的主要工具鏈。

## Decisions

### Decision 1: 採用單次躍升到 `0.1.86`，不逐版停留
- **Decision**: 直接從 `0.1.84` 升到 `0.1.86`。
- **Rationale**: `0.1.85` 與 `0.1.86` 皆為修正導向 release，分兩次升級會增加 lockfile 與回歸成本，價值有限。
- **Alternatives considered**:
  - 先升 `0.1.85` 再升 `0.1.86`：可降低單次變更量，但需要重複驗證與重複提交流程。

### Decision 2: 維持既有 native shim 設計，升級時以契約驗證為主
- **Decision**: 保持 `dist/node_modules/@opentui/core-<platform>-<arch>/index.ts` shim 路徑策略不變。
- **Rationale**: 現行產物契約已被 `core-tui-artifact-contract` 與 `tui-bundle-build` 規範覆蓋；此變更重點在驗證相容性而非重寫載入機制。
- **Alternatives considered**:
  - 改為執行期動態探索 native library 路徑：彈性較高，但會引入新的複雜度與額外風險。

### Decision 3: 新增終端互動回歸檢查作為升級 gate
- **Decision**: 除 `bun install`、`bun run build`、`bun test` 外，新增手動場景驗證（focus/blur、退出後 terminal state、鍵盤連按與畫面完整性）。
- **Rationale**: 上游修正多屬 terminal runtime 行為，單元測試難以覆蓋，需以場景檢查補齊風險。
- **Alternatives considered**:
  - 僅維持自動化命令驗證：執行成本最低，但容易漏掉終端互動 regression。

## Risks / Trade-offs

- [終端相容性差異] 不同 terminal emulator 對 mode restore 行為不一致 → 以至少兩種常用 terminal 執行同一組回歸場景。
- [native 套件命名或檔名變動] 造成 build 後無法載入 `.so/.dylib` → 在 build 驗證中加入產物檔案存在性與啟動檢查。
- [手動驗證成本提高] 升級流程比過去多一段人工檢查 → 以固定最小場景清單控制時間，避免無界探索。

## Migration Plan

1. 更新 `tui/package.json` 的 OpenTUI 版本，重新產生 `tui/bun.lock`。
2. 執行最小自動化驗證：`bun install`、`bun run build`、`bun test`。
3. 執行終端互動回歸清單（focus/blur、quit 後 terminal 可用性、鍵盤操作與畫面渲染）。
4. 若任一關鍵場景失敗，回滾至前一版 lockfile 與依賴版本，保留失敗紀錄後再做相容性調查。

## Open Questions

- 是否要將終端互動回歸場景正式腳本化（例如 smoke test harness），以降低長期人工驗證成本？
- 目前最少要支援哪些 terminal emulator 作為 release gate（例如 Ghostty + WezTerm，或再加上 GNOME Terminal）？
