## 1. Tag-driven Workflow 建置

- [x] 1.1 新增或調整 release workflow，使其在符合規範的 Git tag 推送時自動觸發 AppImage 發版流程
- [x] 1.2 實作 tag 格式驗證與版本擷取，並將版本值作為 workflow 後續步驟的單一來源
- [x] 1.3 串接既有 AppImage 打包流程到 tag-driven workflow，確保可產出 Linux x86_64 AppImage

## 2. 產物與回報規範落地

- [x] 2.1 實作 release 產物命名規則，確保 AppImage 檔名與 tag 版本一致
- [x] 2.2 實作 release metadata 寫入與上傳步驟，確保 metadata 與 tag 版本一致
- [x] 2.3 在建置、封裝、上傳各關鍵階段加入可判讀的失敗回報訊號

## 3. Manual Fallback 與驗證

- [x] 3.1 驗證既有 manual release 流程在新自動化加入後仍可獨立完成交付
- [x] 3.2 更新 release 相關文件，明確說明 tag-driven 主流程與 manual fallback 使用時機
- [x] 3.3 使用測試 tag 演練一次完整 release，確認觸發、命名、上傳與失敗回報符合規格
