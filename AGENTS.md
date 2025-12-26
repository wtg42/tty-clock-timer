# Repository Guidelines

## Project Structure & Module Organization
- `src/main.zig` defines the CLI entry point and wires in the library module.
- `src/root.zig` exposes the reusable module API (imported as `tty_clock_timer`).
- `build.zig` and `build.zig.zon` configure the Zig build and dependencies.

## Build, Test, and Development Commands
- `zig build`: build and install the executable into `zig-out/`.
- `zig build run -- [args]`: build and run the CLI with optional arguments.
- `zig build test`: run all `test` blocks from both the module and executable.
- `zig build test --fuzz`: exercise fuzz tests (see `test "fuzz example"`).

## Coding Style & Naming Conventions
- Indentation: 4 spaces, Zig standard formatting.
- Naming: use `snake_case` for functions/variables and `CamelCase` for types.
- Format Zig sources with `zig fmt src/*.zig` before committing.

## Testing Guidelines
- Tests live inline as Zig `test` blocks inside `src/main.zig` and `src/root.zig`.
- Keep tests focused on public APIs in `src/root.zig` where possible.
- Prefer descriptive test names, e.g., `test "basic add functionality"`.

## Commit & Pull Request Guidelines
- Commit messages: follow a lightweight Conventional Commits style where possible
  (e.g., `chore: add build docs`); keep the subject short and imperative.
- PRs should include: a clear description, relevant test command output, and any
  behavior changes or CLI output examples.

## Configuration & Tips
- Use `zig build --help` to discover supported targets, optimizations, and steps.
- Keep user-facing output in stdout; reserve stderr for diagnostics.

## Agent-Specific Instructions
- 回答請使用繁體中文，專業領域英文單字保留原文。
