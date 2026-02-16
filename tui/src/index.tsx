import { TextAttributes } from "@opentui/core";
import { render, useKeyboard, useRenderer, useTimeline } from "@opentui/solid";
import { createEffect, createSignal, onCleanup, onMount } from "solid-js";

import { createCommandPlane } from "./command_plane.ts";
import { type CommandName, type CommandResponse } from "./protocol.ts";
import { createTimerStore } from "./store.ts";
import {
  type IssuedCommandRecord,
  commandFromKey,
  formatRemaining,
  shouldSkipByDedup,
  shouldSkipByStatus,
} from "./ui_logic.ts";
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
  let lastIssuedCommand: IssuedCommandRecord | null = null;
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
    if (shouldSkipByStatus(projectedStatus, command)) return;

    const dedupDecision = shouldSkipByDedup(
      lastIssuedCommand,
      command,
      Date.now(),
      COMMAND_DEDUP_WINDOW_MS,
    );
    lastIssuedCommand = dedupDecision.next;
    if (dedupDecision.skip) return;

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
