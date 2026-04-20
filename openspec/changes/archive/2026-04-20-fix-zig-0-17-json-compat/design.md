## Context

目前 AppImage 打包流程會先編譯 Core 二進位，但在 Zig 0.17 環境下，`core/src/lib/config.zig` 仍使用舊版 `std.json.Value.object` 初始化與 `put` / `deinit` 介面，導致編譯在設定檔合併邏輯中失敗。問題集中在動態 JSON object 的建構與釋放，並不涉及設定檔格式、CLI 參數或 TUI 互動行為變更。

## Goals / Non-Goals

**Goals:**
- 讓 Core 在 Zig 0.17 / Zig master 標準庫下恢復可編譯狀態
- 保留既有用戶設定檔寫入語意，特別是 `sound` 欄位合併與其他欄位保留
- 讓 AppImage 打包流程不再因 `config.zig` 的舊版 `std` API 用法失敗

**Non-Goals:**
- 不變更 `config.json` 檔案格式
- 不新增新的設定欄位或 CLI 旗標
- 不重寫整個設定檔序列化流程為其他資料模型

## Decisions

### Decision: 只調整 `config.zig` 的動態 JSON object 操作

將修正範圍限制在 `writeConfig` 中建立 `sound` JSON object 的程式碼，避免擴散到其他未受影響模組。

原因：
- 目前 build 失敗點集中明確，風險低且可快速驗證
- 掃描 codebase 後，只有這一段使用了不相容的 `std.json.ObjectMap` 舊介面

替代方案：
- 全面重構設定檔寫入流程，改用 typed struct 重新序列化整份 JSON。這會提高改動面，且目前沒有需求要改變既有合併行為

### Decision: 採用 Zig 0.17 的 `std.json.ObjectMap` 用法

空的 JSON object 將使用 `.empty` 建立，所有 `put` 與 `deinit` 呼叫都顯式傳入 allocator。

原因：
- 這是目前 Zig 0.17 `std.json` / `std.array_hash_map` 已確認存在的標準用法
- 能在不改變行為的前提下恢復編譯

替代方案：
- 直接跳過既有 JSON 合併，改為覆蓋整個設定檔。這會破壞現有需求中「保留其他欄位」的行為，不可接受

### Decision: 用現有 build 與打包入口驗證修正

驗證會優先使用 `zig build` 與既有 AppImage 打包腳本，而不是新增平行驗證工具。

原因：
- 問題最初就是在這兩條實際工作流中暴露
- 直接沿用現有入口能更準確確認修正是否真正解除發佈阻塞

## Risks / Trade-offs

- [只修目前已知錯點，可能在下一次 build 暴露其他 Zig 0.17 不相容處] → 先用 `zig build` 取得新的編譯結果，若有後續錯誤再以同一 change 繼續收斂
- [JSON object 手動釋放流程若 allocator 傳遞不一致，可能引入記憶體管理錯誤] → 保持 allocator 來源一致，僅在既有生命週期內更新 `put` / `deinit` 呼叫
- [打包流程可能還有非 Core 的 Zig 相容性問題] → 先以 Core build 作為必要門檻，再重新跑 AppImage 腳本確認端到端結果
