## 1. Prompt helper build 與依賴

- [x] 1.1 在 `tui/` 新增 `@clack/prompts` 與必要的 args/helper 依賴，並更新 lockfile。
- [x] 1.2 建立獨立 prompt helper entry，定義 `history-select`、`history-delete`、`setup-sound` 三個子命令與 JSON 回傳格式。
- [x] 1.3 更新 Bun build 流程，產出 `tui/dist/prompts/helper.js`，且不把 helper 併入 OpenTUI 主 entry。

## 2. Core 整合

- [x] 2.1 在 `core/src/main.zig` 新增 prompt helper artifact 解析與 spawn 邏輯，取代現有 `gum` binary 查找流程。
- [x] 2.2 將 history 單選與多選刪除流程改接 helper JSON 契約，移除 `gum` 與純 Zig fallback 路徑。
- [x] 2.3 將 `--setup-sound` 流程改接 helper JSON 契約，統一取消與錯誤處理。

## 3. Packaging 與文件

- [x] 3.1 移除 `gum` 下載、來源檢查、AppDir 複製與 verify 規則，改為檢查並打包 `prompts/helper.js`。
- [x] 3.2 更新 AppImage、packaging 與相關文件，移除 `gum` 指南並說明 prompt helper artifact。
- [x] 3.3 清理 repo 內不再需要的 `gum` binary 與腳本引用，確保版本控制中不再維護 `gum`。

## 4. 驗證

- [x] 4.1 補齊或更新 core 與 TUI 端測試，覆蓋 helper 路徑解析、JSON 結果解析與取消/錯誤分支。
- [x] 4.2 執行相關 build/test/verify 流程，確認 TUI bundle、prompt helper 與 AppImage contract 均可通過。
