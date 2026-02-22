## Context

目前 `tty_clock_timer list` 命令支援從歷史記錄中選擇時長並啟動 timer，但無法刪除不需要的項目。歷史記錄儲存在 JSON 檔案中（`~/.local/state/tty-clock-timer/history.json`），包含時長和最後使用時間。gum 已整合到專案中並用於 list 選擇。

## Goals / Non-Goals

**Goals:**
- 實現 `tty_clock_timer list --delete` 進入多選刪除模式
- 支援 gum 的多選功能（--no-limit）讓使用者一次選擇多個項目
- 刪除成功後將剩餘歷史記錄輸出到 stdout
- 空歷史或取消時輸出「no history」
- 不改變現有 `list` 命令的行為（純粹新增 --delete 選項）

**Non-Goals:**
- 不實現刪除前確認流程
- 不提供交互式刪除單個項目的功能
- 不改變歷史記錄的存儲格式
- 不添加新的子命令（整合到 list）

## Decisions

### 1. **整合 --delete 到 list 而非新增獨立子命令**
- **決策**: `list --delete` 而不是 `tty_clock_timer delete`
- **理由**:
  - 保持命令語義清晰（list 既可選擇也可刪除）
  - 減少命令數量，降低使用者認知負擔
  - list 的歷史記錄邏輯已存在，易於擴展
- **替代方案考慮**:
  - 獨立 `delete` 子命令 → 增加命令數，但更明確
  - 互動式流程（list 後詢問是否刪除）→ 不符合使用者需求（需直接進入刪除模式）

### 2. **使用 gum 的多選模式（--no-limit）**
- **決策**: gum choose --no-limit 允許一次選擇多個項目
- **理由**:
  - gum 已整合且可用
  - 多選可一次刪除多個舊項目
  - 使用者體驗優於逐個刪除
- **替代方案考慮**:
  - 單選後需要重複執行 → 冗長，不符合需求
  - 自實現多選 UI → 複雜度高，已有 gum 工具可用

### 3. **刪除邏輯的實現位置**
- **決策**: 在 config.zig 中新增 Command 枚舉值 `list_delete`，在 main.zig 中處理流程
- **理由**:
  - config.zig 負責 CLI 參數解析，新增 list_delete 符合職責
  - main.zig 現有的 resolveDurationFromHistory 邏輯可複用（讀歷史）
  - history.zig 新增刪除函數保持模組職責清晰
- **實現順序**:
  1. config.zig: 解析 "list --delete" → Command.list_delete
  2. history.zig: 新增 deleteEntries(selected_labels) 函數
  3. main.zig: 新增 deleteWithGum() 函數（多選），流程與 chooseWithGum 類似

### 4. **多行輸出處理**
- **決策**: gum 多選輸出為換行分隔，需按行分割後逐一匹配 Entry
- **理由**:
  - gum 的多選模式自然輸出多行（每行一個選中項）
  - 按行分割能簡潔對應 labels 清單
- **實現**: 在 deleteWithGum() 中讀取 gum stdout，按 '\n' 分割，逐行匹配 formatDurationLabel

### 5. **刪除後的輸出格式**
- **決策**: 輸出剩餘歷史記錄，與 list 原有選擇流程輸出一致
- **理由**:
  - 使用者可驗證刪除結果
  - 格式統一，易於理解
- **實現**: 刪除後調用相同的輸出邏輯（使用 formatDurationLabel）

## Risks / Trade-offs

| 風險 | 緩解策略 |
|------|---------|
| gum 多選輸出解析複雜 | 逐行匹配，與現有 chooseWithGum 邏輯一致，測試充分 |
| 誤刪所有歷史記錄 | 設計上不提供確認，但符合需求；使用者可重新記錄新項目 |
| gum 不可用時無降級方案 | 與 list 命令行為一致（無降級），使用者改用手動輸入參數 |
| 多選和單選代碼重複 | 後期可考慮提取公共邏輯重構，目前保持簡單 |

## Migration Plan

1. **部署**:
   - 修改 config.zig、history.zig、main.zig 三個檔案
   - 無資料庫遷移、無 breaking changes
   - 直接發佈新版本

2. **回滾**:
   - 若發現問題，用戶可回到舊版本
   - 歷史檔案格式未變，無相容性問題

3. **使用者文檔**:
   - 更新 help message 加入 `list --delete` 說明

## Open Questions

- 刪除後是否需要重新排序？（目前計畫保留原排序，只刪除項目）
- 若 gum 失敗，是否應降級到文字選單版本的多選？（目前計畫：不降級，輸出錯誤）
- 歷史檔案為空時是否應刪除檔案本身？（目前計畫：保留空檔案）
