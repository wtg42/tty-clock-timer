## Context

`tui/` 目前以 Bun 管理 dependencies，`package.json` 與 `bun.lock` 鎖定 `@opentui/core@0.1.102`、`@opentui/solid@0.1.102`、`solid-js@1.9.11`。npm latest stable 已確認 `@opentui/core` 與 `@opentui/solid` 皆為 `0.4.1`，且 `@opentui/solid@0.4.1` 的 peer dependency 期待 `solid-js@1.9.12`。

既有 TUI 主要依賴 OpenTUI Solid renderer、`useKeyboard`、`useTimeline`、`testRender()`、`@opentui/solid/bun-plugin`，並透過 `tui/build.ts` 將 bundle 與 OpenTUI native library 複製到 `dist/`。升級風險集中在 dependency graph、native optional package 解析、bundle shim 與 headless renderer regression。

## Goals / Non-Goals

**Goals:**

- 以 TDD 方式先確認或補強升級敏感測試，再升級 OpenTUI stack。
- 將 `@opentui/core`、`@opentui/solid` 對齊到 `0.4.1`，並將 `solid-js` 對齊到 `1.9.12`。
- 維持 `bun.lock` 為唯一 lockfile，且安裝樹不得留下多份不同版本 OpenTUI core。
- 確保 `bun run build` 仍能產生可執行 bundle 與 native library shim。
- 透過 renderer integration tests 驗證倒數畫面、完成畫面、錯誤訊息與鍵盤互動。

**Non-Goals:**

- 不重寫 TUI 架構或引入新的 TUI framework。
- 不修改 Zig core 的計時器、IPC 或 config 邏輯，除非驗證發現升級造成必要整合修正。
- 不升級到 snapshot / prerelease OpenTUI 版本。
- 不引入第三方 Zig package。

## Decisions

- **Decision: 使用 npm latest stable 作為升級目標。**  
  `@opentui/core` 與 `@opentui/solid` 必須同批次對齊，避免 `@opentui/solid` nested dependency 帶入另一份 `@opentui/core`。替代方案是只升級到中間版本，但這會保留跨版升級債務，且不符合既有 latest stable 規格。

- **Decision: 先跑/補 TDD safety net，再升級 dependency。**  
  升級前先確認 renderer integration tests 與 build contract tests 覆蓋核心契約；若缺少 OpenTUI `0.4.x` native package handling 的驗證，先補測試讓它在目前實作下失敗，再做最小修正。替代方案是直接升級後看測試結果，但較難證明修正是由測試驅動。

- **Decision: 保留現有 bundle + external native library 模式。**  
  `tui/build.ts` 繼續將 OpenTUI native library 作為外部檔案複製並建立 shim。替代方案是改成完全依賴 runtime `node_modules`，但會破壞 packaged runtime contract。

- **Decision: 將 OpenTUI `0.4.x` 新 native package variants 納入 external handling。**  
  `0.4.1` 新增 `@opentui/core-linux-x64-musl` 與 `@opentui/core-linux-arm64-musl` optional packages。build script 的 external list 必須涵蓋同批次可能解析到的 native packages，避免 bundler 嘗試 inline 或解析錯誤。

## Risks / Trade-offs

- OpenTUI `0.4.1` renderer output 可能有細微字元/佈局差異 → 以 integration tests 驗證使用者可見契約，必要時只調整穩定契約而非過度鎖死 implementation detail。
- Bun install 可能因網路或 registry 權限受限失敗 → 使用明確的 registry 查詢與 install 驗證，失敗時保留現有檔案並回報阻塞原因。
- Native package layout 可能隨平台不同而異 → build script 維持 platform/arch runtime 決策，並用 external list/shim 驗證保護打包路徑。
- AppImage full smoke test 可能依賴本機環境或外部工具 → 至少執行等效 packaged runtime smoke；若 AppImage 工具不可用，記錄缺口並保留自動化 build/test 結果。

## Migration Plan

1. 執行既有 TUI tests，確認目前 safety net 狀態。
2. 補上或調整 build/native package handling 測試，先看見失敗。
3. 更新 `tui/package.json` 版本與 `tui/bun.lock`。
4. 修正 `tui/build.ts` 或測試中暴露的相容性問題。
5. 執行 `bun install`、`bun test`、`bun run build`、integration test 與 packaged runtime smoke。
6. 確認 `bun.lock` 與安裝樹只解析單一 OpenTUI core 版本。

Rollback 可將 `tui/package.json` / `tui/bun.lock` 回到升級前版本，並移除僅為 `0.4.x` native package handling 需要的修正。

## Open Questions

- AppImage smoke 是否能在目前本機環境完整執行；若不能，需以等效 packaged runtime smoke 替代並記錄限制。
