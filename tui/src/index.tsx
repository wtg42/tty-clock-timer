import { TextAttributes } from "@opentui/core";
import { render } from "@opentui/solid";
import { createSignal, onMount } from "solid-js";
import { useTimeline } from "@opentui/solid";

import { createCommandPlane } from "./command_plane.ts";
import { type CommandName, type CommandResponse } from "./protocol.ts";
import { createTimerStore } from "./store.ts";
import { UnixSocketAdapter } from "./unix_socket_adapter.ts";

// Step 1: Read CLI socket override; fallback to default core socket path.
const parseSocketPath = (): string => {
  const socketFlag = "--socket-path";
  const index = process.argv.findIndex((value) => value === socketFlag);
  if (index >= 0 && process.argv[index + 1]) {
    return process.argv[index + 1] as string;
  }
  return "/tmp/tty-clock-timer.sock";
};

// Step 2: Build communication and state primitives.
const socketPath = parseSocketPath();
const adapter = new UnixSocketAdapter(socketPath);
const store = createTimerStore();
const { execute: sendCommand } = createCommandPlane((command) => adapter.sendCommand(command));

// Step 3: Bridge store state into Solid reactive signals.
const [state, setState] = createSignal(store.getState());
const [lastCommandError, setLastCommandError] = createSignal<string | null>(null);

store.subscribe((nextState) => setState(nextState));
adapter.onEvent((event) => store.applyEvent(event));

// Step 4: Convert seconds projection to MM:SS for terminal display.
const formatRemaining = (seconds: number | null) => {
  if (seconds === null) return "--:--";
  const minutes = Math.floor(seconds / 60);
  const remaining = seconds % 60;
  return `${minutes.toString().padStart(2, "0")}:${remaining.toString().padStart(2, "0")}`;
};

// Step 5: Map single-key shortcuts to command names understood by core.
const commandFromKey = (key: string): CommandName | null => {
  switch (key) {
    case "p":
      return "pause";
    case "r":
      return "resume";
    case "s":
      return "reset";
    case "q":
      return "quit";
    default:
      return null;
  }
};

// Step 6: Send command through command plane and update UI error state.
const issueCommand = async (command: CommandName) => {
  let response: CommandResponse;
  try {
    response = await sendCommand(command);
  } catch (error) {
    setLastCommandError(error instanceof Error ? error.message : "command_failed");
    return;
  }

  if (!response.ok) {
    setLastCommandError(response.error);
    return;
  }

  setLastCommandError(null);

  if (command === "quit") {
    // TUI exits after core confirms quit command.
    process.exit(0);
  }
};

// Step 7: Subscribe to raw stdin key stream and dispatch mapped commands.
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk: string | Buffer) => {
  const value = typeof chunk === "string" ? chunk : chunk.toString("utf8");
  for (const char of value) {
    const command = commandFromKey(char.trim());
    if (!command) continue;
    void issueCommand(command);
  }
});

const wait = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

// Step 8: Retry socket connection until core IPC server is ready.
const connectWithRetry = async () => {
  while (true) {
    try {
      await adapter.connect();
      setLastCommandError(null);
      return;
    } catch (error) {
      const message = error instanceof Error ? error.message : "socket_connect_failed";
      setLastCommandError(message);
      await wait(500);
    }
  }
};

// Kick off background connection loop immediately on process start.
void connectWithRetry();

const FinishedView = () => {
  let containerRef: any;
  let titleRef: any;

  const timeline = useTimeline({ autoplay: true });

  onMount(() => {
    timeline.add(containerRef, { opacity: 1, duration: 800, ease: "outBounce" }, 0);
    timeline.add(titleRef, { translateY: -2, duration: 100, ease: "outElastic" }, 800);
    timeline.add(titleRef, { translateY: 0, duration: 100, ease: "outBounce" }, 900);
    timeline.add(
      containerRef,
      {
        opacity: 0.85,
        duration: 1000,
        ease: "inOutQuad",
        loop: true,
        alternate: true,
      },
      1000,
    );
  });

  return (
    <box
      ref={containerRef}
      opacity={0}
      flexDirection="column"
      alignItems="center"
      justifyContent="center"
    >
      <ascii_font ref={titleRef} font="tiny" text="TIME'S UP!" />
      <text attributes={TextAttributes.BOLD}>Press q to exit</text>
    </box>
  );
};

render(() => {
  // Step 9: Render either countdown view or finished animation view.
  return (
    <box alignItems="center" justifyContent="center" flexGrow={1} flexDirection="column">
      {!state().isFinished ? (
        <box justifyContent="center" alignItems="center" flexDirection="column">
          <ascii_font font="tiny" text="TTY Clock Timer" />
          <text attributes={TextAttributes.BOLD}>{formatRemaining(state().remainingSeconds)}</text>
          <text attributes={TextAttributes.DIM}>Status: {state().status}</text>
          <text attributes={TextAttributes.DIM}>Keys: p pause / r resume / s reset / q quit</text>
        </box>
      ) : (
        <FinishedView />
      )}

      {lastCommandError() ? (
        <text attributes={TextAttributes.BOLD}>Command error: {lastCommandError()}</text>
      ) : null}
    </box>
  );
});
