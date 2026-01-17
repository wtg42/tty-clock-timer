# 🤖 AGENTS.md - Agentic Coding Guidelines for tty-clock-timer

這是針對 `tty-clock-timer` 專案的 AI 協作指南。請嚴格遵守以下規範以確保代碼品質與 Zig master 版本一致性。

---

## 📖 文檔與知識獲取優先順序 (Documentation Priority)

> [!IMPORTANT]
> **優先權衝突處理**：禁止優先搜尋網路。Zig `master` 版本變動極快，網路資訊（如 StackOverflow/舊文檔）極易過時。

1.  **第一優先 (Local Source)**：必須調用本地 `zig-std-index` Skill。
    * 模糊搜尋：`bash ./scripts/search.sh <keyword>`
    * 精確讀取：`bash ./scripts/retrieve.sh <symbol>` (例如：`std.time.Timer`)
2.  **第二優先 (Online Reference)**：僅當本地 Skill 找不到資訊時，參考 [Zig Master Docs](https://ziglang.org/documentation/master/)。
3.  **語言偏好**：回答與解釋請使用 **繁體中文**，技術術語（例如：Allocator, Struct, Defer）保留英文原文。

---

## 🛠️ 核心指令 (Quick Commands)

* **Build**: `zig build`
* **Run**: `zig build run -- [args]`
* **Test All**: `zig build test`
* **Test File**: `zig test <file> --test-filter "<pattern>"`
* **Format**: `zig fmt src/*.zig` (提交前必執行)

---

## 📝 程式碼風格 (Code Style)

### **格式與命名 (Formatting & Naming)**
* **縮排**：一律使用 4 空格，完全遵循 `zig fmt` 自動格式化。
* **命名規範**：
    * `snake_case`: 函式、變數、模組名稱。
    * `CamelCase`: 類型 (Types)、結構體 (Structs)。
    * `SCREAMING_SNAKE_CASE`: 常數。
* **長度限制**：單行建議 100-120 字元，禁止手動調整非標準格式。

### **記憶體管理 (Memory Management)**
* **原則**：明確資源生命週期，遵循 RAII 模式。
* **工具選擇**：
    * Debug 模式：使用 `DebugAllocator` 進行洩漏偵測。
    * Release 模式：效能優先使用 `ArenaAllocator`。
* **生命週期**：分配資源後，必須立即使用 `defer` 確保清理。

### **錯誤處理 (Error Handling)**
* **自定義錯誤**：`pub const ParseError = error{ ... };`。
* **錯誤聯集**：回傳類型應標註為 `!ReturnType`。
* **傳播與邊界**：優先使用 `try` 向上傳播，在邊界使用 `catch` 處理。

---

## 🏗️ 專案架構 (Architecture)

### **模組化規劃**
* **單一職責**：每個檔案僅處理一個主結構或一組相關邏輯。
* **封裝**：預設私有，僅對外暴露必要的 `pub` API，並將 `pub` 函式置於檔案前半部。

### **目錄導覽**
* `src/main.zig`: CLI 進入點。
* `src/root.zig`: 庫 (Library) 公開 API。
* `src/lib/config.zig`: 參數解析與配置管理。
* `src/lib/timer.zig`: 核心倒數計時與狀態機邏輯。
* `src/lib/allocator.zig`: 統一的記憶體管理上下文。
* *Planned*: `src/lib/ui.zig` (TTY 繪製) 與 `src/lib/notify.zig` (桌面通知)。

---

## 🧪 測試規範 (Testing)

* **測試位置**：實作檔案內的 `test` 區塊（Inline testing）。
* **命名格式**：`"module/function - scenario"` (例如：`"config/parse - valid minutes"`)。
* **錯誤路徑**：使用 `std.testing.expectError` 驗證預期錯誤。

---

## 📋 Git 工作流與協作

* **提交前檢查**：確保通過 `zig fmt` 與 `zig build test`。
* **訊息語法**：使用英文，遵循 Conventional Commits（`feat:`, `fix:`, `docs:`, `refactor:`）。
* **語言設定**：回答說明請一律使用 **繁體中文**。

---
