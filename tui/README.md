# solid

To install dependencies:

```bash
bun install
```

To run:

```bash
bun dev
```

This project was created using `bun create tui`. [create-tui](https://git.new/create-tui) is the easiest way to get started with OpenTUI.

## IPC Boundary (MVP)

- OpenTUI key actions (`p`/`r`/`s`/`q`) 會先進入 in-process Hono command plane。
- Hono handler 透過 Unix socket adapter 將命令送到 Zig Core。
- Core 事件（`update_timer`、`timer_finished`、`exit`）回流到 Node Store，再驅動畫面。
- Socket path 可用 `--socket-path <path>` 指定，預設 `/tmp/tty-clock-timer.sock`。
