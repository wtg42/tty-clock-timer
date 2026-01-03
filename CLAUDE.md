# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

- `zig build` - Build the executable to `zig-out/`
- `zig build run -- [args]` - Build and run with arguments (e.g., `--minutes 25`)
- `zig build test` - Run all tests from both module and executable
- `zig build test --fuzz` - Run fuzz tests
- `zig fmt src/*.zig` - Format source files before committing

## Architecture

This is a Zig-based CLI countdown timer with tty-clock visual style for Linux terminals.

**Module structure:**
- `src/main.zig` - CLI entry point, imports `tty_clock_timer` module
- `src/root.zig` - Library module exposing public API (imported as `tty_clock_timer`)
- `build.zig` - Build configuration exposing both executable and reusable module

**Planned modules (under `src/lib/`):**
- `timer.zig` - Countdown logic and state management
- `ui.zig` - TTY display and animation effects
- `notify.zig` - Linux desktop notification (via `notify-send`)
- `config.zig` - CLI options and defaults

## Coding Conventions

- 4 spaces indentation, Zig standard formatting
- `snake_case` for functions/variables, `CamelCase` for types
- Tests live inline as `test` blocks, prefer testing public APIs in `src/root.zig`
- stdout for output, stderr for diagnostics

## Language Reference

- **Zig 主要版本**: master
- **Official Zig Documentation**: https://ziglang.org/documentation/master/
- **重要**: 在搜尋跟撰寫時須使用相容 master 版本的函式庫用法
- When working with Zig standard library APIs or language features, always refer to the master documentation first for the most up-to-date information
- Use `zig std` command to explore standard library documentation locally

## Language Preference

回答請使用繁體中文，專業領域英文單字保留原文。
