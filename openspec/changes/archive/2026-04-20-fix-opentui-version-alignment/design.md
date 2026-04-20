## Context

目前 `tui/` 專案的頂層依賴使用 `@opentui/core@0.1.102`，但 `@opentui/solid` 仍停留在 `0.1.92`，而且 `@opentui/solid` 會內嵌自己的 `@opentui/core@0.1.92`。同時，應用程式碼又直接從 `@opentui/core` 匯入 `TextAttributes`，導致 bundle 內同時存在兩份 OpenTUI core。這兩份 core 共用全域 singleton/env registry，啟動時會重複註冊 `OTUI_DUMP_CAPTURES` 並因設定不一致而崩潰，最終讓 AppImage 雖然打包成功但無法執行。

## Goals / Non-Goals

**Goals:**
- 讓 `@opentui/core` 與 `@opentui/solid` 對齊到同一批穩定版本
- 確保 TUI bundle 僅包含一份 OpenTUI core，不再因重複 env registry 註冊而崩潰
- 補足升級驗證，確認 `bun build`、測試與 AppImage runtime smoke test 都能通過

**Non-Goals:**
- 不重寫 TUI 畫面結構或互動邏輯
- 不變更 Zig core 與 Unix socket IPC 設計
- 不引入新的 TUI framework 或替換 OpenTUI

## Decisions

### Decision: 將 `@opentui/core` 與 `@opentui/solid` 升級到同一批版本

主專案依賴與 `@opentui/solid` 內部依賴必須一致，避免 lockfile 安裝出 nested duplicate 的 OpenTUI core。

原因：
- 問題根因就是版本漂移造成的雙 core 安裝
- 對齊版本比單純在 bundler 做 alias 更穩定，能同時修正本地執行、bundle 與 AppImage runtime

替代方案：
- 只在 bundler 端做 alias 或 external 規則。這可能掩蓋問題，但 lockfile 與本地依賴樹仍不一致，風險較高

### Decision: 優先從 `@opentui/solid` 取得可重用 export，避免 app 直接拉第二條 core 匯入路徑

若 `@opentui/solid` 已 re-export `TextAttributes` 等既有需要的符號，應用程式碼優先經由 `@opentui/solid` 使用，降低 bundle 引入額外 module graph 的機會。

原因：
- 問題目前就是從 app 直接引入 `@opentui/core` 與 `@opentui/solid` 兩條路徑
- 這能讓應用層的 import 面更單純，減少未來再次引入雙 core 的機會

替代方案：
- 保留直接從 `@opentui/core` 匯入，只依賴版本對齊。這雖可能運作，但對未來升級較脆弱

### Decision: 升級驗證需同時覆蓋 lockfile、bundle 與打包後 runtime

驗證不只看 `bun run build`，還要確認安裝樹沒有多份 OpenTUI core，並以 AppImage 或等效 runtime 路徑做 smoke test。

原因：
- 這次實際故障是在打包後執行才暴露，不是單純編譯錯誤
- 只做單點 build/test 無法保證 singleton/env registry 問題已消失

## Risks / Trade-offs

- [升級 `@opentui/solid` 後可能帶來 API 或 peer 行為差異] → 以現有 build、unit/integration test 與 runtime smoke test 一起驗證
- [單純改 import 路徑但未完全清理 lockfile，仍可能留下雙版本安裝] → 明確要求更新 `bun.lock` 並檢查安裝樹
- [OpenTUI 新版本可能變更 native shim 或 bundler 行為] → 將 `bun run build` 與 AppImage smoke test 都納入最小驗證
