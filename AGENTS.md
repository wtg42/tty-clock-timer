# 🤖 AGENTS.md - Agentic Coding Guidelines for tty-clock-timer

這是針對 `tty-clock-timer` 專案的 AI 協作指南。請嚴格遵守以下規範以確保代碼品質、Zig master 版本一致性、以及 core/tui 功能分工清晰。

---

## 📄 OpenSpec 變更管理 (OpenSpec Change Workflow)

- **方針**：所有功能/修正都以 OpenSpec change 流程管理；避免使用獨立計劃書格式。
- **工件產出**：依 OpenSpec 預設流程建立 change 與 artifacts（需求、設計、任務、驗證）。
- **實作節點**：僅在 artifacts 完成且需求明確後進入實作。
- **歸檔機制**：完成實作與驗證後，依 OpenSpec 預設規則封存 change。
- **常用指令**：`/opsx:new`、`/opsx:ff`、`/opsx:apply`、`/opsx:archive`。
- **語言**：使用繁體中文，技術術語保留英文。

---

## 📖 文檔與知識獲取優先順序 (Documentation Priority)

> [!IMPORTANT]
> **優先權衝突處理**：禁止優先搜尋網路。Zig `master` 版本變動極快，網路資訊（如 StackOverflow/舊文檔）極易過時。

### 所有 Claude Code 實例必須遵守

1.  **第一優先 (Local Source)**：當遇到任何 Zig std 查詢，**必須主動調用本地 `zig-std-index` 脚本**，不得跳過。
    - 模糊搜尋：`bash .opencode/skill/zig-std-index/scripts/search.sh <keyword>`
    - 精確讀取：`bash .opencode/skill/zig-std-index/scripts/retrieve.sh <symbol>` (例如：`std.time.Timer`)
    - **例外情境**：脚本執行失敗或返回空結果時，才參考線上資源。
2.  **第二優先 (Online Reference)**：僅當本地脚本找不到資訊時，參考 [Zig Master Docs](https://ziglang.org/documentation/master/std/)。
3.  **實作前驗證**：開始實作任何使用 std 函式的功能前，必須使用脚本查詢該函式是否存在及正確用法，以避免使用不存在或已變更的 API。
4.  **禁止推測**：不得依賴知識庫記憶推測 Zig API。優先相信脚本與本地源碼結果。
5.  **子代理指示**：若需委派 Task 進行 Zig 相關研究，在 prompt 中明確指示使用脚本：
    > "使用以下命令查詢 Zig std 庫：
    > bash .opencode/skill/zig-std-index/scripts/search.sh <keyword>
    > bash .opencode/skill/zig-std-index/scripts/retrieve.sh <symbol>"
6.  **語言偏好**：回答與解釋請使用 **繁體中文**，技術術語（例如：Allocator, Struct, Defer）保留英文原文。

---

## 🔄 子代理工具使用規範 (Subagent Guidelines)

當使用 `task` 工具啟動任何類型的子代理（`general` 或 `explore`）時，**必須遵守以下規範**：

### **適用範圍**
- **所有子代理類型**：一旦涉及 Zig std 查詢，強制使用脚本
- **general 代理**：研究 Zig std 相關問題
- **explore 代理**：搜索代碼庫時若涉及 Zig API 查詢

### **強制使用本地脚本**
- **明確指示**：在委派給子代理的 prompt 中，**必須明確要求**使用脚本
- **禁止自行搜索**：子代理不得自行網路搜索或依賴記憶推測 Zig API
- **脚本路徑**：使用相對於專案根目錄的路徑：
  ```bash
  bash .opencode/skill/zig-std-index/scripts/search.sh <keyword>
  bash .opencode/skill/zig-std-index/scripts/retrieve.sh <symbol>
  ```

### **正確指令範例**

```zig
// ❌ 錯誤：讓子代理自行搜索
task({
    description: "Search Zig std",
    prompt: "Search for fcntl in Zig standard library",
    subagent_type: "explore"
})

// ✅ 正確：明確要求使用脚本
task({
    description: "Search Zig std for fcntl",
    prompt: "使用以下命令查詢 Zig std 庫中的 fcntl：
bash .opencode/skill/zig-std-index/scripts/search.sh 'fcntl'
如果找到相關符號，再用 retrieve.sh 讀取完整源碼。",
    subagent_type: "explore"
})
```

### **資訊驗證機制**
- 若子代理回報的資訊涉及 Zig API 存在性、函式簽名、結構體欄位：
  1. **必須**使用脚本再次驗證
  2. **或**執行 `zig build` 編譯驗證
- **不信任原則**：對於子代理提供的 Zig API 資訊保持質疑，優先相信脚本與本地源碼結果

### **錯誤處理**
- 若子代理無法找到所需資訊，**不得**允許其推測或網路搜索
- 正確做法：回報給父代理，由我直接使用脚本查詢或參考官方文件

---

## 🧑‍💻 主 Claude Code 實例的 Zig 查詢工作流

**原則**：當遇到任何 Zig std 問題或需要驗證 API 時，主動使用脚本，不要跳過。

### 工作流

1. **遇到 Zig std 問題**
   - 例：「如何使用 `std.time.Timer`？」
   - 例：「`std.fs.Dir.openDir` 的簽名是什麼？」

2. **主動執行搜尋**
   ```bash
   bash .opencode/skill/zig-std-index/scripts/search.sh Timer
   ```

3. **根據搜尋結果精確讀取**
   ```bash
   bash .opencode/skill/zig-std-index/scripts/retrieve.sh std.time.Timer
   ```

4. **分析源碼和文檔註解**
   - 讀取返回的源碼
   - 查看 `///` 開頭的文檔註解
   - 驗證函式簽名、參數、返回值

5. **回答用戶或進行實作**
   - 基於實際源碼而非推測回答
   - 開始實作前再次驗證 API 變更

### 不遵守後果

- **推測 API**：導致實作錯誤、編譯失敗
- **依賴舊知識**：使用已廢棄或變更的 API
- **浪費時間**：反復修正編譯錯誤

---

## 📁 專案範圍與分工 (Scope)

- `core/`：CLI 核心功能（Zig）。
- `tui/`：OpenTUI 畫面功能（TypeScript + Solid）。
- 修改任何核心邏輯先看 `core/src`，修改 UI 先看 `tui/src`。

---

## 🛠️ 指令總覽 (Commands)

### Core (Zig)

- **Build**：`zig build`（在 `core/` 目錄執行）
- **Run**：`zig build run -- [args]`
- **Test All**：`zig build test`
- **Test File**：`zig test core/src/lib/config.zig --test-filter "parseArgsFromSlice"`
- **Format**：`zig fmt core/src/*.zig core/src/lib/*.zig`

### TUI (OpenTUI)

- **Dev**：`bun run dev`（在 `tui/` 目錄執行）
- **Lint/Test**：目前未提供 lint 或 test script（不要假設存在）
- **Type Check**：目前未提供專用命令（`tsconfig.json` 設為 `noEmit`）

---

## 🧪 測試規範 (Testing)

- **測試位置**：Zig 實作檔案內的 `test` 區塊（Inline testing）。
- **命名格式**：`"module/function - scenario"`（例如：`"config/parse - valid minutes"`）。
- **錯誤路徑**：使用 `std.testing.expectError` 驗證預期錯誤。
- **單檔/單測試**：優先使用 `zig test <file> --test-filter "<pattern>"` 精準跑測試。

---

## 🧱 架構與檔案導覽 (Architecture)

### Core (Zig)

- `core/src/main.zig`：CLI 進入點，負責參數解析、I/O、錯誤處理。
- `core/src/root.zig`：Library 公開 API。
- `core/src/lib/config.zig`：CLI 參數解析與設定。
- `core/src/lib/timer.zig`：倒數計時與狀態機（核心邏輯）。
- `core/src/lib/allocator.zig`：統一記憶體管理上下文。
- `core/src/lib/ipc.zig`：IPC 管理，與 OpenTUI 子進程通訊。

### TUI (OpenTUI)

- `tui/src/index.tsx`：OpenTUI 入口與 UI 組裝。
- `tui/tsconfig.json`：TypeScript 設定，`strict: true`、`noEmit: true`。

### UI 重構架構

採用 **Zig + Embedded Node.js SEA**：
```
tty_clock_timer (單一執行檔)
├── Zig 主程序 (CLI + Timer + IPC)
└── Embedded Node.js SEA (OpenTUI UI)
```

---

## 📝 程式碼風格 (Code Style)

### Zig 通用規範

- **縮排**：4 空格，完全依賴 `zig fmt`。
- **單行長度**：建議 100-120 字元，禁止手動拆行破壞格式。
- **imports**：先 `std`，再外部模組，最後本地模組；避免不必要的別名。
- **命名**：
  - `snake_case`：函式、變數、模組。
  - `CamelCase`：Types、Structs。
  - `SCREAMING_SNAKE_CASE`：常數。
- **公開 API**：`pub` 函式集中在檔案前半段，並保持最小化可見範圍。

### Zig 記憶體管理

- 明確資源生命週期，遵循 RAII。
- Debug 模式使用 `DebugAllocator` 偵測洩漏。
- Release 模式優先 `ArenaAllocator`（效能）。
- 分配後立刻 `defer` 清理，確保 early-return 也會釋放。
- 參考 `core/src/lib/allocator.zig` 的 allocator context 實作。

### Zig 錯誤處理

- 自定義錯誤集合：`pub const ParseError = error{ ... };`。
- 回傳型別使用錯誤聯集：`!ReturnType`。
- 內部流程優先 `try` 傳播，邊界（CLI/IO）使用 `catch` 轉為使用者訊息。

### Zig 類型與資料

- CLI/計時器使用明確整數型別（例如 `u32` 秒數）。
- 乘法/轉換需處理溢位，使用 `std.math.mul` 或 `std.fmt.parseInt` 的錯誤回傳。
- logging 用 `std.log`，錯誤輸出與 usage 使用 writer/print。

### TUI (TypeScript/TSX)

- **格式**：沿用現有風格（2 空格縮排）。
- **imports**：第三方（`@opentui/*`、`solid-js`）在前，本地模組在後。
- **型別**：遵守 `tsconfig.json` 的 `strict: true`。
- **JSX**：使用 `@opentui/solid` 的 JSX runtime，保持目前的 `<box>`、`<text>` 樣式。
- **副作用**：入口檔只負責 render，狀態邏輯請獨立模組化。

---

## ✅ 格式化與提交前檢查 (Pre-commit)

- Zig 變更必跑：`zig fmt core/src/*.zig core/src/lib/*.zig`。
- 測試建議：`zig build test`。
- git commit 訊息使用英文，遵循 Conventional Commits（`feat:`, `fix:`, `docs:`, `refactor:`）。

---

## 🧭 Cursor / Copilot 規則

- 未發現 `.cursor/rules/`、`.cursorrules`、或 `.github/copilot-instructions.md`。

---

## 🧩 其他注意事項

- `core/` 與 `tui/` 的依賴與工具鏈獨立，請勿混用指令。

---
