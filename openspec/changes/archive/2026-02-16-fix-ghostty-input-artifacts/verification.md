# Manual Verification Checklist

## Environment Matrix

- [ ] Ghostty (non-tmux)
- [ ] tmux (`TERM=tmux-256color`)

## Input Hygiene

- [ ] Run `zig build run -- -s 10` in Ghostty without pressing any key for 10 seconds
- [ ] Confirm no `Command error: invalid_state` appears automatically

## Repeat Key Behavior

- [ ] Hold `p` while timer transitions to paused
- [ ] Confirm UI does not flood repeated `invalid_state` errors

## Terminal Cleanup

- [ ] Quit via `q` in Ghostty and verify terminal text is selectable after exit
- [ ] Quit via `q` in tmux and verify terminal text is selectable after exit

## Regression

- [ ] Run `zig build test` in `core/`
- [ ] Record result in implementation notes / PR description
