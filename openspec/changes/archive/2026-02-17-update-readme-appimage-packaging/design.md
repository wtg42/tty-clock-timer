## Context

`README.md` 是專案的主要入口文檔，目前記錄了核心架構、系統流程、快速開始等資訊。隨著 AppImage 打包工作流的確立（`packaging/appimage/`），以及 Core-TUI artifact contract 和 Unix socket IPC bridge 規格的建立，主 README 需要補充相關內容以反映完整的構建與分發流程。

目前 AppImage 相關資訊分散在：
- `packaging/appimage/README.md` - 詳細的打包工作流
- `packaging/appimage/artifact-contract.md` - artifact 契約
- `openspec/specs/` - 相關規格文檔

## Goals / Non-Goals

**Goals:**
- 在主 README 中新增 AppImage 發佈與分發章節
- 說明 AppImage 打包的目的與運行環境
- 記錄 Core 動態產生唯一 socket path 在 AppImage 環保中的應用
- 提供往 `packaging/appimage/` 詳細文檔的導航

**Non-Goals:**
- 不更改已在 `packaging/appimage/` 中的詳細文檔
- 不修改 Core 或 TUI 的實現邏輯
- 不改變 artifact contract 或 IPC 規格

## Decisions

1. **章節位置**：在「快速開始」之後、「開發指南」之前新增「AppImage 發佈」章節，強調這是完整工作流的一部分

2. **內容組織**：
   - AppImage 簡介與目的
   - 運行環境契約概述（指向 artifact-contract.md）
   - socket path 動態生成機制
   - 構建與驗證快速參考（指向 packaging/appimage/README.md）

3. **文檔導航**：使用相對連結指向 `packaging/appimage/` 詳細文檔，避免重複

## Risks / Trade-offs

- **風險**：README 內容可能與 `packaging/appimage/` 文檔重複 → 保持高層次總結，詳細步驟指向專用文檔
- **平衡**：新增內容不應讓 README 過長 → 控制在 100-150 行左右，重點放在「為什麼」而非「怎麼做」
