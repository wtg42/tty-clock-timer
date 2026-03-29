# tui-render-integration-tests Specification

## Purpose
TBD - synced from change align-opentui-stack. Update Purpose after archive.

## Requirements

### Requirement: TUI MUST 提供 OpenTUI renderer-based integration tests
系統 MUST 提供以 OpenTUI headless renderer 與 `@opentui/solid` `testRender()` 為基礎的 integration tests，用於驗證 TUI 在 dependency upgrade 前後的主要畫面契約與互動行為。

#### Scenario: 以 headless renderer 驗證主畫面
- **WHEN** 維護者執行 TUI integration tests
- **THEN** 測試套件 MUST 能在不啟動真實終端機視窗的情況下驗證主畫面的關鍵文字輸出與佈局契約

### Requirement: Integration tests MUST 覆蓋升級敏感的 UI 契約
integration tests MUST 至少覆蓋倒數畫面、完成畫面、錯誤訊息與 keyboard interaction 等升級敏感的 UI 契約，避免 OpenTUI 或 SolidJS 升級後發生未被偵測的行為漂移。

#### Scenario: 驗證完成畫面契約
- **WHEN** TUI 狀態投影為已完成
- **THEN** integration test MUST 驗證完成畫面仍顯示預期的完成訊息與重新開始/離開提示

#### Scenario: 驗證 keyboard interaction 契約
- **WHEN** integration test 模擬符合支援範圍的按鍵事件
- **THEN** TUI MUST 觸發對應命令流程或狀態更新，且不依賴人工手動驗證

### Requirement: Integration tests SHALL 可穩定獨立執行
系統 SHALL 提供可重複執行的 integration test 入口，讓維護者可在版本對齊或 API 調整期間獨立重跑 UI regression checks。

#### Scenario: 單獨執行 integration tests
- **WHEN** 維護者使用測試 filter 或指定檔案方式執行 TUI integration tests
- **THEN** 測試結果 SHALL 可穩定重現，且失敗案例可對應到具體的 UI 契約
