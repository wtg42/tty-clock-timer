## Context

目前 AppImage 打包流程已要求 Linux x86_64 `gum` 必須存在於 `packaging/tools/gum/linux-x64/gum`，但來源仍偏向人工放置。當 repository 不再追蹤 binary 時，CI 與本機環境都需要一致的工具準備步驟，否則會出現「本機可打包、CI 失敗」或「版本漂移無法追蹤」的問題。

此外，`gum` 屬於打包期依賴，不應直接納入 Git 版本控管。需要把下載流程腳本化，並把版本與 checksum 集中管理，確保供應來源可驗證且可重現。

## Goals / Non-Goals

**Goals:**
- 提供單一腳本 `fetch-gum.sh`，統一本機與 CI 的 `gum` 下載流程。
- 將 `gum` 版本與 checksum 固定於腳本，下載後必須驗證完整性。
- CI release workflow 在打包前強制執行該腳本。
- 避免 binary 誤提交：`packaging/tools/gum/` 加入 `.gitignore`。

**Non-Goals:**
- 不處理 Linux x86_64 以外平台的 `gum` 下載。
- 不更動現有 `package-appimage.sh` 對 `gum` 路徑契約。
- 不新增額外 package manager 依賴（維持 shell + curl/tar/sha256sum）。

## Decisions

### Decision 1: 下載流程集中在 `packaging/appimage/scripts/fetch-gum.sh`

- 腳本輸出固定為 `packaging/tools/gum/linux-x64/gum`。
- 腳本負責：建立目錄、下載 release tarball、checksum 驗證、解壓與安裝 executable bit。

**Alternatives considered:**
- 直接在 GitHub Actions YAML 寫下載邏輯：會造成本機與 CI 邏輯重複。
- 由 `package-appimage.sh` 內嵌下載：會把「工具準備」與「打包」耦合，降低可維護性。

### Decision 2: 版本與 checksum 在腳本內單一來源管理

- 使用常數（例如 `GUM_VERSION`, `GUM_SHA256`）作為唯一來源。
- CI 與本機皆呼叫同一腳本，避免不同流程抓到不同版本。

**Alternatives considered:**
- 使用 latest release：不可重現，風險高。
- 把 checksum 放 workflow secrets：不利審閱，且對公開工具不必要。

### Decision 3: workflow 明確新增「prepare gum」階段

- 在 tag-driven release workflow 的打包前加入 fetch 腳本步驟。
- 失敗時應在 workflow log 中可辨識為工具準備失敗。

**Alternatives considered:**
- 依賴 runner 預裝 `gum`：環境不可控，不符合 artifact 契約。

### Decision 4: `.gitignore` 忽略 `packaging/tools/gum/`

- 防止本機下載後誤提交 binary。
- 保留 `packaging/tools/appimagetool.AppImage` 現有策略不變。

## Risks / Trade-offs

- **[下載來源變更]** 上游 release 檔名或路徑改動 → 腳本 fail fast，需更新腳本常數。
- **[checksum 更新成本]** 升版需同步更新 checksum → 以單一腳本集中降低維護成本。
- **[CI 依賴網路]** GitHub 連線異常會導致打包失敗 → 明確失敗階段，便於重試與 fallback manual release。

## Migration Plan

1. 新增 `fetch-gum.sh` 並在本機驗證可下載與安裝 `gum`。
2. 更新 tag-driven release workflow，打包前呼叫 `fetch-gum.sh`。
3. 更新 `.gitignore` 忽略 `packaging/tools/gum/`。
4. 更新 `packaging/appimage/release.md`，說明本機前置可使用 fetch 腳本。
5. 執行 AppImage build/package/verify 與 workflow dry-run 驗證。

Rollback strategy:
- 若下載流程不穩，可暫時恢復人工放置 `gum` binary，但仍保留 precheck 以避免靜默失敗。

## Open Questions

- 是否需要在 `fetch-gum.sh` 支援鏡像來源（例如內部 cache）以降低外網波動風險？
