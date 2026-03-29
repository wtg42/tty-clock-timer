## Context

`tty-clock-timer` 的 TUI 目前建立在 OpenTUI Solid binding 與 Bun build 流程之上，核心入口集中在 `tui/src/index.tsx`，並透過 `tui/build.ts` 處理 `@opentui/solid/bun-plugin`、native package external 與 `libopentui.so` shim。現況雖可運作，但相依版本仍落在較早的 OpenTUI / SolidJS 組合，和 upstream 最新文件與 peer expectation 有落差。

現有測試主要覆蓋 pure function 與 protocol/store 邏輯，對 OpenTUI render output、keyboard hook wiring、完成畫面與錯誤畫面的整合行為缺乏保護。這使 dependency upgrade 容易落入「能編譯、能啟動，但互動或畫面契約悄悄漂移」的風險。

## Goals / Non-Goals

**Goals:**
- 將 `@opentui/core`、`@opentui/solid` 與 `solid-js` 對齊到目前 upstream 相容組合，降低未來升級落差。
- 以 TDD 方式先建立 OpenTUI renderer-based regression coverage，再進行相依升級。
- 確保既有 timer 畫面、完成畫面、錯誤訊息與 keyboard interaction 在升級後維持既定契約。
- 驗證 `tui/build.ts` 的 bundle/native shim contract 在升級後仍成立。

**Non-Goals:**
- 不主動重設 TUI 視覺風格或互動模型。
- 不為了追逐新 API 而全面改寫現有可正常運作的 OpenTUI usage。
- 不在本次變更中擴張 timer 功能範圍或修改 core IPC 協定。

## Decisions

### Decision: 以 upstream 相容版本組合為升級目標，而不是各套件各自追最新
- 決定先將 `@opentui/core` 與 `@opentui/solid` 對齊同一 release line，並將 `solid-js` 對齊該版 peer expectation。
- 理由：OpenTUI 仍未進入正式穩定版，跨套件的相依相容性比單點追最新更重要。
- 替代方案：直接將 `solid-js` 升到 npm 最新版。未採用，因為這可能引入 peer mismatch，增加額外噪音。

### Decision: 先補 renderer-based tests，再升級相依版本
- 決定先補 `@opentui/solid` `testRender()` 與 `@opentui/core/testing` 驗證，再調整 dependency versions。
- 理由：本次風險主要是 render 與 interaction drift，不是單純 TypeScript type break；測試必須先把目前契約釘住。
- 替代方案：直接升級後用人工 smoke test 驗證。未採用，因為難以穩定重現 regressions，也不利於未來繼續升級。

### Decision: 將測試分層為 pure function tests 與 OpenTUI integration tests
- 保留既有 function-level test 檔案，另外新增 renderer-based integration test，避免把 UI 整合行為塞進純函式測試能力中。
- 理由：這能保留現有測試的速度與定位，同時讓升級驗證擁有更貼近真實 runtime 的保護層。
- 替代方案：只保留 integration tests。未採用，因為會失去小範圍邏輯回歸的快速定位能力。

### Decision: 保留既有 build shim 架構，但把它納入升級驗證契約
- 繼續使用 `tui/build.ts` 內的 native package external 與 `dist/node_modules/@opentui/core-<platform>-<arch>/index.ts` shim，並以規格與測試驗證它在新版 OpenTUI 下仍成立。
- 理由：這個方案已經符合目前 packaging contract，調整成本低，且可直接驗證是否仍與新版 packaging/export 行為相容。
- 替代方案：重寫 bundling/loading 策略。未採用，因為那會把本次工作從版本對齊擴張成 packaging redesign。

## Risks / Trade-offs

- [OpenTUI minor release 在未正式穩定前仍可能帶來行為差異] → 先補 render 與 interaction regression tests，再進行版本調整。
- [Solid peer alignment 可能引入額外 type 或 runtime 行為差異] → 以 OpenTUI peer expectation 為準，避免各套件獨立漂移。
- [Build shim 依賴 native package export 形狀] → 在 build contract 與 artifact 驗證中明確檢查 external package name、shim 路徑與 runtime 啟動行為。
- [TDD 新增的 integration tests 可能較脆弱] → 優先檢查穩定的文字契約與關鍵互動，不過度依賴容易抖動的細節 snapshot。

## Migration Plan

1. 先新增 renderer-based integration tests，固定目前 UI 契約與互動行為。
2. 調整 `tui/package.json` 的 OpenTUI / SolidJS versions，必要時同步更新 lockfile。
3. 依測試結果修正 API 或 build 差異，並重新驗證 bundle/native shim contract。
4. 執行 TUI 測試與 build，確認升級後可維持既有行為。

若升級過程出現無法接受的相容性問題，回退策略為恢復前一版 dependency set，保留新測試以作為下一輪升級基準。

## Open Questions

- 是否需要在本次升級中同步引入 OpenTUI 新 hook 或新 component API，或僅維持現有 usage 並先完成版本對齊。
- 是否需要為 build artifact contract 增加更接近 packaging 流程的驗證腳本，而不只是在 `tui/` 內部驗證 bundle。
