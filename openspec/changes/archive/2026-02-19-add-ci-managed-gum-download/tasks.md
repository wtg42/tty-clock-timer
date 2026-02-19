## 1. 建立共用 gum 下載腳本

- [x] 1.1 新增 `packaging/appimage/scripts/fetch-gum.sh`，實作 Linux x86_64 gum 下載、解壓與安裝到 `packaging/tools/gum/linux-x64/gum`
- [x] 1.2 在腳本內固定 `gum` 版本與 checksum，下載後執行完整性驗證，失敗時非零退出
- [x] 1.3 撰寫腳本使用說明與錯誤訊息，讓本機與 CI 都可直接採用

## 2. 串接 CI release workflow

- [x] 2.1 更新 `.github/workflows/tag-driven-appimage-release.yml`，在打包前加入 `fetch-gum.sh` 步驟
- [x] 2.2 確保 workflow 於 gum 準備失敗時中止，且 log 可辨識為工具準備階段失敗

## 3. 儲存庫與文件同步

- [x] 3.1 更新 `.gitignore` 忽略 `packaging/tools/gum/`，避免誤提交下載後 binary
- [x] 3.2 更新 `packaging/appimage/release.md`，說明以 `fetch-gum.sh` 作為本機前置步驟
- [x] 3.3 執行 `openspec validate add-ci-managed-gum-download --strict` 並修正驗證問題
