# Project Notes

## Zig Implementation Policy

- The Zig part of this project uses only the Zig standard library (`std`).
- Do not introduce third-party Zig packages unless the user explicitly asks for it.
- Prefer `std` solutions first when implementing, refactoring, or explaining Zig code.

## LLM Working Guidance

- When working on Zig code, assume `std` is the default and expected toolset.
- Keep Zig changes simple and easy to read.
- Prefer direct, explicit code over clever abstractions.
- When explaining Zig code, mention the relevant `std` modules and why they are used.

## Planning Guidance

- When planning specs for frontend or TUI work, consider using the `opentui` skill to explore screen structure, interaction flow, and terminal UI behavior.
- When planning specs for Zig backend work, consider using the `zig-std-explorer` or `zig-std-index` skill to verify `std` APIs and implementation options before writing the spec.
