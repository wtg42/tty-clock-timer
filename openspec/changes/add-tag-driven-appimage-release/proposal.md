## Why

目前 AppImage 發版流程以 manual release 為主，缺少可重複且可追溯的 tag-driven 自動化流程，導致維護者在每次釋出時需手動操作並承擔步驟遺漏風險。為了降低發版摩擦並提升釋出一致性，需要補上以 Git tag 觸發的標準化 release 能力。

## What Changes

- 新增以 Git tag 觸發的 AppImage release 流程，於 tag 建立後自動執行建置與封裝。
- 定義 release 產物命名與版本對齊規則，確保 AppImage 檔名、release metadata 與 tag 一致。
- 建立失敗回報與基本驗證要求，讓維護者可快速判斷 release 是否可交付。
- 保留既有 manual release 能力作為 fallback，不將其移除。

## Capabilities

### New Capabilities
- `tag-driven-appimage-release`: 定義以版本 tag 觸發的 AppImage 自動發版需求、產物規則與失敗處理。

### Modified Capabilities
- `appimage-packaging-workflow`: 既有發版能力需補充「可透過 tag-driven 自動化完成交付且與 manual release 共存」的需求邊界。

## Impact

- Affected specs: `appimage-packaging-workflow`（修改）、`tag-driven-appimage-release`（新增）
- Affected code: GitHub Actions release workflow、`packaging/appimage` 相關打包腳本與 release 文件
- Affected systems: Git tag 發版流程、GitHub Releases 產物上傳與驗證回報
