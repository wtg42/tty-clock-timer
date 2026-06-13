## 1. TDD Safety Net

- [x] 1.1 執行現有 `tui/` 測試，記錄升級前 renderer integration 與 unit tests 狀態。
- [x] 1.2 補上 build/native package handling 測試，驗證 OpenTUI native package variants 必須維持 external。
- [x] 1.3 確認新增測試在目前實作下可觀察到失敗，作為升級前的 TDD red step。

## 2. Dependency Upgrade

- [x] 2.1 將 `@opentui/core` 與 `@opentui/solid` 更新到 latest stable `0.4.1`。
- [x] 2.2 將 `solid-js` 對齊 `@opentui/solid@0.4.1` 的 peer expectation。
- [x] 2.3 使用 Bun 更新 `tui/bun.lock`，並確認沒有產生其他 lockfile。

## 3. Compatibility Fixes

- [x] 3.1 修正 `tui/build.ts` 的 OpenTUI native package external list，使 `0.4.x` 新 native variants 不會被 bundler inline。
- [x] 3.2 驗證 native library copy 與 `dist/node_modules/@opentui/core-<platform>-<arch>/index.ts` shim 仍能解析目前平台 native library。
- [x] 3.3 確認安裝樹與 lockfile 不會解析出多份不同版本的 `@opentui/core`。

## 4. Verification

- [x] 4.1 成功執行 `bun install`。
- [x] 4.2 成功執行 `bun test`。
- [x] 4.3 成功執行 `bun run build`。
- [x] 4.4 成功執行 integration test 入口，確認倒數畫面、完成畫面、錯誤訊息與鍵盤互動契約。
- [x] 4.5 執行 AppImage 或等效 packaged runtime smoke test，確認 bundle 啟動不發生 duplicate OpenTUI env registry registration error。
- [x] 4.6 更新本 checklist，將已完成項目標記為完成。
