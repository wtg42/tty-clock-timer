# macOS Core–TUI Artifact Contract

macOS MVP 支援 Apple Silicon (`arm64`)。發佈產物是可搬移的 `.tar.gz`，但不包含 Bun；使用者必須先讓 `bun` 可從 `PATH` 執行。

## Archive Layout

```text
tty-clock-timer-<version>-macos-arm64/
├── bin/ttc
├── libexec/tty-clock-timer/ttc
└── lib/tty-clock-timer/tui/
    ├── index.js
    ├── prompts/helper.js
    ├── libopentui.dylib
    └── node_modules/@opentui/core-darwin-arm64/index.ts
```

`bin/ttc` 是薄 launcher，只能解析 archive root、檢查 Bun、設定 `TTY_CLOCK_TUI_CWD`、`TTY_CLOCK_TUI_ENTRY` 與 `TTY_CLOCK_PROMPT_HELPER_ENTRY`，然後以 `exec` 轉交 Zig core。TUI 必須由 core 啟動及管理，launcher 不得直接啟動 TUI。

整個解壓目錄可移動，但不能只複製 `bin/ttc`。macOS native library 固定為 `libopentui.dylib`，不得以 Linux 的 `libopentui.so` 代替。

