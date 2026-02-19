## Context

README.md 目前為純文字說明，缺少視覺示例。使用者初次閱讀時難以直觀理解產品外觀。

## Goals / Non-Goals

**Goals:**
- 在 README 標題下方加入產品截圖
- 建立標準化的截圖存放位置（`assets/screenshots/`）
- 使用相對路徑連結，確保 portable 和可維護性

**Non-Goals:**
- 不修改現有的架構說明或快速開始章節
- 不新增多個截圖場景（僅「計時中」一張）
- 不涉及圖片壓縮或自動化生成

## Decisions

| 決策 | 選擇 | 理由 |
|------|------|------|
| 截圖位置 | 標題下方，副標題前 | 最先吸引注意力，建立視覺認知 |
| 存放位置 | `assets/screenshots/` | 遵循社群慣例，未來可擴展（logo、diagram 等） |
| 檔案名 | `timer-running.png` | 描述性命名，清楚表達內容 |
| 連結方式 | 相對路徑 `./assets/screenshots/timer-running.png` | Portable、GitHub 預覽友善、易於遷移 |
| 圖片尺寸 | 縮放適當寬度 | 適應 README 排版，避免過大或過小 |
| 描述文字 | 簡潔一句 | 保持 README 簡潔，不冗長 |

## Risks / Trade-offs

| 風險 | 緩解方案 |
|------|----------|
| 圖片檔案大小 | 使用者手動將圖片放置後驗證，確認尺寸合理 |
| 相對路徑在不同分支失效 | 相對路徑在 git 中穩定，僅需確保檔案存在 |
| 截圖過期（UI 改變） | 作為視覺資源，由維護者在 UI 更新時手動更新 |

## Implementation Approach

1. 修改 README.md：在「# tty-clock-timer」後插入圖片 markdown
2. 建立目錄結構：`assets/screenshots/`
3. 準備待驗證：使用相對路徑連結至 `timer-running.png`，由使用者手動放置並驗證
