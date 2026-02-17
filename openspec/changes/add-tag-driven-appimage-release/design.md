## Context

目前專案已具備 `packaging/appimage` 的 manual release 與可執行 AppImage 打包能力，但缺少「由版本 tag 直接驅動 release」的標準流程。維護者在釋出時需手動執行多步驟，容易出現版本命名不一致、漏附產物或狀態不透明等問題。此變更涉及 CI workflow、打包腳本介面與 release metadata，屬於跨模組流程設計。

## Goals / Non-Goals

**Goals:**
- 以 Git tag 作為唯一 release 觸發來源，建立可重複執行的 AppImage 發版流程。
- 明確定義 tag、AppImage 檔名與 release metadata 的版本對齊規則。
- 在自動化流程中提供可判讀的成功/失敗訊號，縮短維護者排查時間。
- 保持 manual release 可用，避免在自動化初期造成交付中斷風險。

**Non-Goals:**
- 不在本次變更中引入多平台發版（僅維持 Linux x86_64 AppImage）。
- 不在本次變更中重構現有 timer/core/tui 功能邏輯。
- 不要求一次完成完整 release governance（如 changelog 生成、簽章、通知整合）。

## Decisions

- Decision: 採用 Git tag 觸發 CI release workflow，而非手動 dispatch。
  - Rationale: tag 能自然對齊版本語意並保留 immutable 歷史，降低人為輸入版本錯誤。
  - Alternatives considered:
    - workflow_dispatch: 彈性高但易輸入錯誤版本字串。
    - 定時排程: 無法精準對齊釋出時機。

- Decision: 版本來源以 tag 字串為單一真相，產物命名與 release metadata MUST 同步使用該版本。
  - Rationale: 減少多處版本配置不一致導致的追溯困難。
  - Alternatives considered:
    - 從原始碼檔案讀版本再比對 tag: 增加同步成本與失配風險。

- Decision: 保留 manual release 作為 fallback，不將其移除。
  - Rationale: 自動化初期可避免 CI 環境異常造成無法發版。
  - Alternatives considered:
    - 全面切換自動化並移除手動流程: 轉換風險過高。

- Decision: 將驗證與錯誤回報視為 release 流程的一部分，要求在失敗時輸出明確失敗階段。
  - Rationale: 維護者可快速定位是建置、封裝或上傳階段失敗。
  - Alternatives considered:
    - 僅依賴通用 CI 失敗訊號: 診斷資訊不足。

## Risks / Trade-offs

- [Tag 命名不符合規範導致流程失敗] → 在流程入口加入 tag 格式驗證並回報可採用格式。
- [CI 環境工具差異導致打包不穩定] → 固定 appimagetool 來源與步驟，並保留 manual fallback。
- [自動化流程與既有文件不同步] → 於變更內同步更新 release 文件與命名規則。
- [維護者誤以為 manual release 已淘汰] → 在規格與文件明確標示 manual 為可用備援路徑。

## Migration Plan

1. 先新增 tag-driven release workflow 與版本命名規則，不更動既有 manual 腳本行為。
2. 在測試 tag 上演練完整流程，確認建置、封裝、上傳與失敗回報符合規格。
3. 更新 release 文件，說明自動化流程與 manual fallback 的使用時機。
4. 若自動化異常，立即回退至 manual release 路徑完成交付。

## Open Questions

- 是否需要限定 tag 前綴（例如 `v`）為強制規則，或允許多種格式並正規化。
- 是否在本階段就要求將 checksum 一併附加到 release assets。
