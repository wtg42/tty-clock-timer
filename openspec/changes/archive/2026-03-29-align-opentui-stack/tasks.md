## 1. 測試基線建立

- [x] 1.1 盤點現有 `tui/` 測試覆蓋範圍，確認哪些畫面與互動契約尚未被保護
- [x] 1.2 新增以 OpenTUI test renderer 或 `@opentui/solid` `testRender()` 為基礎的 integration test 骨架
- [x] 1.3 為倒數主畫面、完成畫面與錯誤訊息建立 renderer-based regression tests
- [x] 1.4 為 keyboard interaction 建立可重複執行的整合測試，驗證按鍵事件會觸發對應命令流程

## 2. 相依版本對齊

- [x] 2.1 更新 `tui/package.json` 中的 `@opentui/core`、`@opentui/solid` 與 `solid-js` 版本至目標相容組合
- [x] 2.2 更新 lockfile 或安裝後產物，確保 OpenTUI 與 SolidJS 相依圖一致
- [x] 2.3 依測試與型別結果調整 TUI 程式碼中的 OpenTUI / Solid API 使用差異

## 3. Build 與 runtime contract 驗證

- [x] 3.1 驗證 `tui/build.ts` 的 bun plugin、external native package 與 shim 路徑在新版相依下仍可運作
- [x] 3.2 確認 build 後產物仍符合 `tui-bundle-build` 與 `core-tui-artifact-contract` 的 bundle/native library 契約
- [x] 3.3 若升級造成 build 或 runtime contract 差異，調整實作並補上相應測試或驗證案例

## 4. 回歸驗證與收尾

- [x] 4.1 執行 function-level tests 與新增的 renderer-based integration tests，確認結果可穩定重現
- [x] 4.2 執行 `bun run build` 驗證 TUI bundle 可成功產出
- [x] 4.3 檢查升級後的主畫面、完成畫面與錯誤訊息是否符合既有顯示契約，整理必要的變更說明
