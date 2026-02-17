## Context

目前專案已具備 Zig core 與 TUI runtime 的分層，但缺乏可重現的 AppImage 打包流程與對應契約文件，導致每次發版都需臨時拼裝。此變更先鎖定 Linux x86_64，目標是建立可擴充的 packaging foundation，並維持「core 啟動 UI」的既有架構責任。另因 AppImage 常在不同掛載路徑與暫存環境執行，IPC socket path 若固定，容易與既有實例衝突。

## Goals / Non-Goals

**Goals:**
- 提供 `packaging/appimage` 最小骨架，定義輸入產物、輸出 AppImage、與手動 release 步驟。
- 定義 core 與 TUI runtime artifact contract，明確 runtime 資產位置、啟動入口、與參數約定。
- 使 AppImage MVP 可驗收：可啟動 timer、可使用 key commands、可由 core 啟動 UI。
- 建立唯一 socket path 策略，避免多實例或殘留檔案導致 IPC 失敗。

**Non-Goals:**
- 不在本次建立完整 CI/CD 自動發布流程。
- 不在本次擴充到非 x86_64 Linux 平台。
- 不重構計時核心邏輯或改變 TUI 主要交互設計。

## Decisions

1. 先建 foundation、後做自動化
- 決策：先提供可手動執行的打包骨架與驗收路徑，不直接導入 release pipeline。
- 理由：可先驗證產物形態與執行契約，降低一次性導入自動化的除錯成本。
- 替代方案：直接建立 CI release job；缺點是故障面較廣，難快速定位核心問題。

2. 保持 core 啟動 UI 的責任邊界
- 決策：AppImage 執行入口仍由 core 驅動 TUI runtime 啟動，不由外部包裝腳本接管流程控制。
- 理由：維持現有架構一致性，避免雙重啟動路徑造成行為分岐。
- 替代方案：讓 AppRun 直接啟動 Node/UI；缺點是會削弱 core 對生命週期與 IPC 的控制。

3. 明確化 artifact contract
- 決策：以文件化契約定義 core 執行檔、TUI runtime artifact、必要環境變數與路徑解析規則。
- 理由：打包層、core、TUI 可獨立演進但維持兼容，降低隱性耦合。
- 替代方案：只靠程式碼默契；缺點是跨模組修改容易破壞封裝且難審查。

4. Socket path 採唯一化策略
- 決策：每次啟動生成具唯一性的 socket path（含 PID/隨機後綴或等效機制），並在退出時清理。
- 理由：避免 AppImage 重複執行、異常退出後殘留檔案、或跨掛載點衝突。
- 替代方案：固定 socket path；缺點是衝突率高且恢復流程複雜。

## Risks / Trade-offs

- [手動流程仍依賴操作者一致性] → 以文件化步驟與固定目錄結構降低操作差異。
- [contract 過早凍結造成後續調整成本] → 在 MVP 階段僅約束必要欄位，保留擴充欄位。
- [唯一 socket path 提升除錯複雜度] → 在 log 中輸出實際 path 並提供清理策略。
- [AppImage 環境差異導致路徑解析問題] → 將路徑規則寫入 contract 並納入 MVP 手動驗證清單。

## Migration Plan

1. 新增 `packaging/appimage` 骨架與說明文件，定義輸入與輸出介面。
2. 建立 artifact contract 文件並對齊 core 啟動 UI、IPC path 規則。
3. 產出 Linux x86_64 AppImage，執行 timer 與 key commands 的手動驗收。
4. 若驗收失敗，回退至未打包執行方式，僅保留文件與骨架，不影響既有執行路徑。

## Open Questions

- unique socket path 的具體格式是否要對外穩定（供外部工具觀測）或僅內部保證唯一性。
- TUI runtime artifact 是否需要版本標記欄位，以支援未來獨立升級策略。
