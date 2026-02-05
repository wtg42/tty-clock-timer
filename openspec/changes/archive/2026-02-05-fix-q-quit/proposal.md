## Why

計時結束後無法直接按下 q 結束程式，必須輸入「q enter q」才會退出，導致使用者操作直覺被打斷且容易誤判程式是否卡住。

## What Changes

- 修正計時結束後的輸入處理，按下 q 即可立即結束程式，不需搭配 Enter 或重複輸入。
- 統一計時進行中與結束後的退出鍵行為，避免狀態切換造成不一致。

## Capabilities

### New Capabilities
- `quit-on-q`: 在計時器進行中或結束後，按下 q 立即結束程式，不需要 Enter。

### Modified Capabilities

## Impact

- CLI 輸入處理流程（core）
- TUI 鍵盤輸入與 IPC 訊息處理（若有）
- 相關狀態切換與退出路徑的測試或紀錄
