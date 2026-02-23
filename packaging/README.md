# Packaging

This directory contains packaging and release assets for `tty-clock-timer`. The current distribution target is **AppImage** (Linux x86_64).

## Directory Layout

```text
packaging/
├── README.md            <- this document
├── appimage/            <- AppImage scaffold, scripts, and assets
│   ├── README.md        <- AppImage detailed docs
│   ├── artifact-contract.md
│   ├── checklist.md
│   ├── release.md
│   ├── verification.md
│   ├── assets/          <- .desktop and icon files
│   └── scripts/         <- build / package / verify scripts
├── tools/               <- external tools (for example, appimagetool)
└── out/                 <- build outputs (git-ignored)
    └── appimage/        <- AppImage and intermediate artifacts
```

## Environment Requirements

| Tool | Version | Description |
|------|------|------|
| `zig` | 0.16+ | Builds the core binary |
| `bun` | 1.x | TUI runtime (must be installed on host) |
| `appimagetool` | - | Packages AppDir into `.AppImage`; place at `packaging/tools/appimagetool.AppImage` or set `APPIMAGETOOL_BIN` |

You can download `appimagetool` from [GitHub Releases](https://github.com/AppImage/appimagetool/releases).

## Quick Start

```bash
# 1. Build core binary
./packaging/appimage/scripts/build-core.sh

# 2. Package AppImage
APPIMAGE_VERSION=0.1.0 ./packaging/appimage/scripts/package-appimage.sh

# 3. Verify artifact
APPIMAGE_VERSION=0.1.0 ./packaging/appimage/scripts/verify-artifact.sh
```

Output path: `packaging/out/appimage/tty-clock-timer-<version>-linux-x86_64.AppImage`

## FAQ

### What if `appimagetool` cannot be found?

Scripts resolve `appimagetool` in this order:
1. Path specified by the `APPIMAGETOOL_BIN` environment variable
2. `packaging/tools/appimagetool.AppImage`
3. `appimagetool` found in system `PATH`

Recommended: put the downloaded binary at `packaging/tools/appimagetool.AppImage` and mark it executable.

### Why does AppImage still require host `bun`?

The TUI runtime is currently packaged as source (`tui/`) and does not embed the `bun` binary yet. AppImage `AppRun` calls host `bun` to execute the TUI. This is a known limitation and may be replaced by a bundled runtime later.

### How is `APPIMAGE_VERSION` used?

This environment variable controls output naming and version tags. If unset, it defaults to `dev`:

```bash
# Output: tty-clock-timer-dev-linux-x86_64.AppImage
./packaging/appimage/scripts/package-appimage.sh

# Output: tty-clock-timer-1.0.0-linux-x86_64.AppImage
APPIMAGE_VERSION=1.0.0 ./packaging/appimage/scripts/package-appimage.sh
```

### Can I delete the `out/` directory?

Yes. `packaging/out/` contains build artifacts and can be safely removed and rebuilt.

## Detailed Docs

- [AppImage packaging guide](appimage/README.md)
- [Release Playbook](appimage/release.md)
- [Artifact Contract](appimage/artifact-contract.md)
- [Packaging checklist](appimage/checklist.md)
- [Verification record](appimage/verification.md)
