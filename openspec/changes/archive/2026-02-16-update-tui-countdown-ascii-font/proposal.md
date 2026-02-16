## Why

目前首頁倒數時間以一般文字顯示，辨識度不足，無法在終端機畫面中快速聚焦主資訊。改為使用 `<ascii_font>` 呈現可提高可讀性，同時維持既有操作習慣與狀態回饋。

## What Changes

- 將首頁倒數計時顯示改為 `<ascii_font>` 呈現
- 保留既有控制鍵提示與狀態資訊區塊，不改變行為與語意
- 維持目前由 Core 事件驅動的顯示更新流程

## Capabilities

### New Capabilities

### Modified Capabilities
- `tui-timer-display`: 調整倒數區塊呈現樣式為 ASCII font，並要求保留控制鍵與狀態資訊

## Impact

- `tui/src/index.tsx`: 倒數顯示組件改為 `<ascii_font>` 輸出
- `tui` 顯示層相關模組：調整版面以容納 ASCII font 字形高度
