## 1. CI 對齊

- [x] 1.1 更新 `tag-driven-appimage-release` 主 spec，移除 `gum` 準備流程並改寫為 Bun + prompt helper artifact 契約。
- [x] 1.2 檢查 workflow 是否仍殘留 `gum` 假設；若有，補齊最小對齊修正。
- [x] 1.3 驗證 spec 與 `.github/workflows/tag-driven-appimage-release.yml` 一致，並勾選完成。
- [x] 1.4 更新 `appimage-packaging-workflow` 主 spec，對齊目前最小 `node_modules` shim artifact 現況。
