---
description: Load zig-std-index skill and inspect Zig std source from local ZVM
---

Load the zig-std-index skill and use it to find or retrieve Zig standard library symbols.

## Workflow

### Step 1: Load zig-std-index skill

```ts
skill({ name: 'zig-std-index' })
```

### Step 2: Determine intent from $ARGUMENTS

- If user provides a vague keyword, run search first.
- If user provides a concrete symbol path (for example `std.time.Timer`), run retrieval directly.

### Step 3: Execute the correct script

- Search mode:
  ```bash
  bash .opencode/skill/zig-std-index/scripts/search.sh "<keyword>"
  ```
- Retrieve mode:
  ```bash
  bash .opencode/skill/zig-std-index/scripts/retrieve.sh "<symbol>"
  ```

### Step 4: Return useful output

- For search: show likely matching symbols and suggest the best retrieval target.
- For retrieve: summarize key signatures/doc comments and answer the user question from source.

<user-request>
$ARGUMENTS
</user-request>
