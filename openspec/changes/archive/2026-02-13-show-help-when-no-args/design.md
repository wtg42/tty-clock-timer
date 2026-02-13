## Context

目前 `core/src/lib/config.zig` 在無參數時回傳 `MissingArguments`，由 `core/src/main.zig` 統一印錯誤並以非 0 結束。
現況雖有簡短 usage，但在 `zig build run --` 下會疊加 build runner 的 failure 訊息，造成使用者對「是否為預期行為」的判讀成本偏高。
本次變更範圍集中在 CLI 參數解析與使用者提示，不涉及 timer 狀態機、IPC 協定或 TUI 呈現流程。

## Goals / Non-Goals

**Goals:**
- 讓 CLI 在無參數時輸出完整 help 內容，降低首次使用摩擦。
- 明確定義無參數情境語意為「說明模式」而非「錯誤模式」。
- 保持既有 `--help`、`--minutes`、`--seconds` 行為一致且可測試。

**Non-Goals:**
- 不調整計時器執行邏輯與 IPC 訊息格式。
- 不新增其他 CLI 旗標（例如 `--version`、互動式 wizard）。
- 不變更 TUI 畫面內容與鍵盤操作流程。

## Decisions

- 決策 1：將「無參數」視為 help 路徑
  - Rationale：使用者意圖通常是先了解用法，直接顯示完整 help 比單行錯誤更符合 CLI onboarding。
  - Alternative：維持錯誤碼 1 並印更長 usage；雖可行，但仍偏懲罰式體驗。

- 決策 2：help 內容以單一輸出來源維護
  - Rationale：避免 `--help` 與「無參數」產生文案分岐，降低日後維護成本。
  - Alternative：兩套獨立輸出；可客製語氣但容易漂移。

- 決策 3：保留其他 parse error 為錯誤語意
  - Rationale：像未知旗標、缺值、非數字仍屬輸入錯誤，需維持可被腳本辨識的失敗語意。
  - Alternative：所有錯誤都降級為 help；會掩蓋真錯誤並降低自動化可觀測性。

## Risks / Trade-offs

- [Risk] 既有依賴「無參數必定失敗」的腳本語意改變 → Mitigation：在 spec 與 release note 明示此變更，並保持其他錯誤碼策略不變。
- [Trade-off] 友善體驗提升，但部分使用者可能偏好嚴格模式 → Mitigation：未來若有需求可再引入明確 strict flag，不在本次範圍。
- [Risk] help 文案未同步更新造成測試脆弱 → Mitigation：以穩定關鍵片段驗證並集中輸出來源。
