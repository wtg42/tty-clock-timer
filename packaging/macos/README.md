# macOS Packaging

此流程只支援 Apple Silicon (`Darwin arm64`)，輸出：

```text
packaging/out/macos/tty-clock-timer-<version>-macos-arm64.tar.gz
packaging/out/macos/tty-clock-timer-<version>-macos-arm64.tar.gz.sha256
```

## Requirements

- macOS on Apple Silicon
- Zig master / 0.17-compatible toolchain
- Bun 1.x
- 已透過 `bun install --frozen-lockfile` 安裝 `tui/` dependencies

## Commands

```bash
MACOS_VERSION=v1.0.0 ./packaging/macos/scripts/package-macos.sh
MACOS_VERSION=v1.0.0 ./packaging/macos/scripts/verify-artifact.sh
MACOS_VERSION=v1.0.0 ./packaging/macos/scripts/test-failures.sh
```

詳細 runtime layout 見 [artifact-contract.md](artifact-contract.md)。產物未 codesign 或 notarize，不是 self-contained runtime，也不支援 Intel Mac 或 Universal Binary。

