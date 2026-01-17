---
name: zig-std-index
description: Provides tools to fuzzy search and retrieve source code from the Zig standard library (ZVM path). Use this when searching for std symbols or reading their implementation.
license: MIT
compatibility: opencode
metadata:
  category: docs
  purpose: search
allowed-tools: bash curl
---

# Zig Standard Library Index Skill

I help you discover and read the Zig standard library source code directly from your local ZVM installation.

## When to use me

- When you need to find a Zig std symbol but only have a keyword.
- When you need to see the actual implementation or doc comments of a Zig function (e.g., std.debug.print).

## Instructions for AI

When the user asks about Zig standard library features, follow this workflow:

1. **Discovery**: If the symbol name is unknown or vague, execute `bash ./scripts/search.sh <keyword>`. This will return matching files and pub definitions.
2. **Retrieval**: After identifying the correct symbol, execute `bash ./scripts/retrieve.sh <symbol>` (e.g., `std.time.Timer`). This will output the raw source code.
3. **Analysis**: Read the returned source code and doc comments (starting with `///`) to answer the user's question accurately.

Note: All scripts are located in the `./scripts/` directory relative to this skill.
