## Why

目前主 README.md 缺少 AppImage 打包與分發相關的資訊。隨著 AppImage 打包工作流與 Core-TUI artifact contract 的確立，需要在主 README 中補充這些內容，幫助使用者和維護者理解打包流程與分發方式。

## What Changes

- 在主 README 中增加 AppImage 打包與分發章節
- 說明 AppImage 的運行環境契約（runtime artifact contract）
- 記錄 socket path 的動態生成機制在 AppImage 環境中的應用
- 提供 AppImage 構建與驗證的快速參考

## Capabilities

### New Capabilities

無新建 capabilities。此變更為文檔更新，基於現有規格進行整合。

### Modified Capabilities

無規格層級的需求變更。

## Impact

- **受影響檔案**：`README.md` 主文件
- **受影響文檔**：`packaging/appimage/` 相關文檔的內容參考
- **無 API 或功能變更**
