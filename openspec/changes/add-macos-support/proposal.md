## Why

目前專案僅提供 Linux x86_64 AppImage，macOS 使用者無法取得經驗證、可直接安裝的發佈產物。現有 Zig、Bun、OpenTUI 與 Unix Domain Socket 架構已具備 Darwin 基礎，因此現在適合先交付 Apple Silicon MVP，並用獨立流程隔離平台差異。

## What Changes

- 新增 macOS arm64 的 build、package、verify、smoke test 與 tag-driven release 流程，產出版本化 `.tar.gz`。
- 將 Zig core、TUI bundle、prompt helper 與 `libopentui.dylib` 組裝為明確且可驗證的 macOS runtime layout。
- 將 Bun 定義為 macOS MVP 的外部 runtime prerequisite；本次不封裝 Bun。
- 在音效設定中偵測 macOS 內建的 `afplay`。
- 讓 Unix socket path 優先使用有效的系統暫存目錄，並在不適用時安全 fallback 至 `/tmp`，同時遵守 Unix socket path 長度限制。
- 在 macOS arm64 CI runner 驗證 Zig core、TUI bundle、IPC 啟動與打包產物。
- 更新 macOS 安裝、Bun prerequisite、已知 Gatekeeper/quarantine 限制與驗證方式的文件。
- 明確排除 Intel Mac、Universal Binary、Homebrew、bundled Bun、codesign、notarization，以及 config/history 搬遷至 `~/Library/Application Support`。

## Capabilities

### New Capabilities

- `macos-packaging-workflow`: 定義 macOS arm64 runtime layout、版本化 tarball、驗證、smoke test、CI 與 tag-driven release 行為。

### Modified Capabilities

- `sound-setup-cli`: 將 macOS 內建 `afplay` 納入常見播放器自動偵測。
- `unix-socket-ipc-bridge`: 將唯一 socket path 的暫存目錄解析與路徑長度安全行為擴充至 macOS。
- `core-tui-artifact-contract`: 讓 core–TUI runtime contract 同時涵蓋 AppImage 與 macOS `.dylib` bundle layout。
- `build-compatibility`: 明確要求 core 與 TUI 在 macOS arm64 的受支援工具鏈上完成 build 與測試。

## Impact

- 受影響程式：`core/src/main.zig`、TUI build 設定與相關測試。
- 新增系統：`packaging/macos/` 與 macOS GitHub Actions workflows。
- 受影響文件：根目錄 README、packaging 文件與 runtime artifact contract。
- Runtime dependency：macOS 使用者必須可從 `PATH` 執行 Bun；OpenTUI 使用 Darwin arm64 native package。
- 發佈風險：MVP 產物不進行 codesign/notarization，必須文件化 Gatekeeper/quarantine 限制。
