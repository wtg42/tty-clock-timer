import { TextAttributes } from "@opentui/core";
import { render, useKeyboard, useRenderer, useTimeline } from "@opentui/solid";
import { createEffect, createSignal, onCleanup, onMount } from "solid-js";

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

const COMMAND_DEDUP_WINDOW_MS = 250;
const ERROR_DEDUP_WINDOW_MS = 1000;

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

const wait = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

// Step 6: Retry socket connection until core IPC server is ready.
const connectWithRetry = async (options: {
  shouldStop: () => boolean;
  setError: (message: string | null) => void;
}) => {
  while (!options.shouldStop()) {
    try {
      await adapter.connect();
      options.setError(null);
      return;
    } catch (error) {
      const message = error instanceof Error ? error.message : "socket_connect_failed";
      options.setError(message);
      await wait(500);
    }
  }
};

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

const App = () => {
  // Step 7: Bind OpenTUI keyboard events and enforce graceful shutdown.
  const renderer = useRenderer();

  let shuttingDown = false;
  let commandInFlight = false;
  let projectedStatus = state().status;
  let lastIssuedCommand: { command: CommandName; at: number } | null = null;
  let lastError: { message: string; at: number } | null = null;

  const setCommandError = (message: string | null) => {
    if (message === null) {
      lastError = null;
      setLastCommandError(null);
      return;
    }

    if (message === "invalid_state") {
      setLastCommandError(null);
      return;
    }

    const now = Date.now();
    if (lastError && lastError.message === message && now - lastError.at < ERROR_DEDUP_WINDOW_MS) {
      return;
    }

    lastError = { message, at: now };
    setLastCommandError(message);
  };

  const shouldSkipByStatus = (command: CommandName) => {
    const current = projectedStatus;
    if (command === "pause") return current !== "running";
    if (command === "resume") return current !== "paused";
    return false;
  };

  const shouldSkipByDedup = (command: CommandName) => {
    const now = Date.now();
    if (lastIssuedCommand && lastIssuedCommand.command === command) {
      if (now - lastIssuedCommand.at < COMMAND_DEDUP_WINDOW_MS) {
        return true;
      }
    }
    lastIssuedCommand = { command, at: now };
    return false;
  };

  const shutdown = async () => {
    if (shuttingDown) return;
    shuttingDown = true;

    await adapter.disconnect();

    renderer.destroy();

    const forceExit = setTimeout(() => {
      process.exit(0);
    }, 50);
    forceExit.unref();
  };

  const issueCommand = async (command: CommandName) => {
    if (shuttingDown) return;
    if (commandInFlight) return;
    if (shouldSkipByStatus(command)) return;
    if (shouldSkipByDedup(command)) return;

    commandInFlight = true;

    let response: CommandResponse;
    try {
      response = await sendCommand(command);
    } catch (error) {
      setCommandError(error instanceof Error ? error.message : "command_failed");
      commandInFlight = false;
      return;
    }

    if (!response.ok) {
      setCommandError(response.error);
      commandInFlight = false;
      return;
    }

    if (command === "pause") {
      projectedStatus = "paused";
    } else if (command === "resume" || command === "reset") {
      projectedStatus = "running";
    } else if (command === "quit") {
      projectedStatus = "finished";
    }

    setCommandError(null);
    commandInFlight = false;

    if (command === "quit") {
      await shutdown();
    }
  };

  useKeyboard((key) => {
    if (shuttingDown) return;
    if (key.eventType !== "press") return;

    const command = commandFromKey(key.name);
    if (!command) return;

    void issueCommand(command);
  });

  const unsubscribeStore = store.subscribe((nextState) => setState(nextState));
  const unsubscribeEvents = adapter.onEvent((event) => store.applyEvent(event));
  onCleanup(() => {
    unsubscribeStore();
    unsubscribeEvents();
  });

  void connectWithRetry({
    shouldStop: () => shuttingDown,
    setError: setCommandError,
  });

  createEffect(() => {
    projectedStatus = state().status;

    if (state().shouldExit) {
      void shutdown();
    }
  });

  // Step 8: Render either countdown view or finished animation view.
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
};

render(() => <App />);
