import { TextAttributes } from "@opentui/core";
import { render } from "@opentui/solid";
import { createSignal, onMount } from "solid-js";
import { useTimeline } from "@opentui/solid";

const SERVER_URL = process.env.SERVER_URL || "http://localhost:8080";

type SSEUpdateMessage = {
  type: "update_timer";
  remaining_seconds: number;
  total_duration: number;
  status: string;
};

type SSEFinishedMessage = {
  type: "timer_finished";
  total_duration: number;
};

type SSEErrorMessage = {
  type: "error";
  message: string;
};

const isSSEUpdateMessage = (value: unknown): value is SSEUpdateMessage => {
  if (!value || typeof value !== "object") return false;
  const record = value as Record<string, unknown>;
  return (
    record.type === "update_timer" &&
    typeof record.remaining_seconds === "number" &&
    typeof record.total_duration === "number" &&
    typeof record.status === "string"
  );
};

const isSSEFinishedMessage = (value: unknown): value is SSEFinishedMessage => {
  if (!value || typeof value !== "object") return false;
  const record = value as Record<string, unknown>;
  return (
    record.type === "timer_finished" &&
    typeof record.total_duration === "number"
  );
};

const isSSEErrorMessage = (value: unknown): value is SSEErrorMessage => {
  if (!value || typeof value !== "object") return false;
  const record = value as Record<string, unknown>;
  return (
    record.type === "error" &&
    typeof record.message === "string"
  );
};

const [remainingSeconds, setRemainingSeconds] = createSignal<number | null>(null);
const [timerStatus, setTimerStatus] = createSignal<string>("idle");
const [isFinished, setIsFinished] = createSignal<boolean>(false);
const [connectionError, setConnectionError] = createSignal<string | null>(null);

const formatRemaining = (seconds: number | null) => {
  if (seconds === null) return "--:--";
  const minutes = Math.floor(seconds / 60);
  const remaining = seconds % 60;
  return `${minutes.toString().padStart(2, "0")}:${remaining.toString().padStart(2, "0")}`;
};

const handleSSEMessage = (data: string) => {
  const trimmed = data.trim();
  if (!trimmed) return;
  let parsed: unknown;
  try {
    parsed = JSON.parse(trimmed);
  } catch {
    return;
  }
  if (isSSEUpdateMessage(parsed)) {
    setRemainingSeconds(parsed.remaining_seconds);
    setTimerStatus(parsed.status);
    setConnectionError(null);
  } else if (isSSEFinishedMessage(parsed)) {
    setIsFinished(true);
    setConnectionError(null);
  } else if (isSSEErrorMessage(parsed)) {
    setConnectionError(parsed.message);
  }
};

// Setup keyboard input handling
const setupKeyboardInput = () => {
  process.stdin.setRawMode(true);
  process.stdin.setEncoding("utf8");

  process.stdin.on("data", async (chunk) => {
    const key = chunk.toString();
    if (key === "q" || key === "Q") {
      try {
        await fetch(`${SERVER_URL}/stop`, { method: "POST" });
      } catch {
        // Ignore errors, just exit
      }
      process.exit(0);
    } else if (key === " ") {
      // Pause/resume
      try {
        if (timerStatus() === "running") {
          await fetch(`${SERVER_URL}/pause`, { method: "POST" });
        } else if (timerStatus() === "paused") {
          await fetch(`${SERVER_URL}/resume`, { method: "POST" });
        }
      } catch {
        // Ignore errors
      }
    }
  });
};

// Setup SSE connection
const setupSSEConnection = () => {
  try {
    const eventSource = new EventSource(`${SERVER_URL}/events`);

    eventSource.addEventListener("message", (event) => {
      handleSSEMessage(event.data);
    });

    eventSource.addEventListener("error", () => {
      setConnectionError("Server connection lost");
      eventSource.close();
      // Attempt reconnect after delay
      setTimeout(setupSSEConnection, 1000);
    });

    eventSource.addEventListener("open", () => {
      setConnectionError(null);
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Connection failed";
    setConnectionError(message);
    // Retry after delay
    setTimeout(setupSSEConnection, 1000);
  }
};

// Timer finished celebration view with animations
const FinishedView = () => {
  let containerRef: any;
  let titleRef: any;

  const timeline = useTimeline({ autoplay: true });

  onMount(() => {
    // Sequence 1: Fade in + bounce entrance (0-800ms)
    timeline.add(
      containerRef,
      { opacity: 1, duration: 800, ease: "outBounce" },
      0
    );

    // Sequence 2: Title upward bounce (800-1000ms)
    timeline.add(
      titleRef,
      { translateY: -2, duration: 100, ease: "outElastic" },
      800
    );
    timeline.add(
      titleRef,
      { translateY: 0, duration: 100, ease: "outBounce" },
      900
    );

    // Sequence 3: Breathing loop (1000ms+)
    timeline.add(
      containerRef,
      {
        opacity: 0.85,
        duration: 1000,
        ease: "inOutQuad",
        loop: true,
        alternate: true,
      },
      1000
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
      <text attributes={TextAttributes.BOLD}>Press 'q' to exit</text>
    </box>
  );
};

// Error view
const ErrorView = () => {
  return (
    <box flexDirection="column" alignItems="center" justifyContent="center">
      <text attributes={TextAttributes.BOLD}>{connectionError()}</text>
      <text attributes={TextAttributes.DIM}>Attempting to reconnect...</text>
    </box>
  );
};

// Initialize on mount
onMount(() => {
  setupSSEConnection();
  setupKeyboardInput();
});

// OpenTUI rendering
render(() => (
  <box alignItems="center" justifyContent="center" flexGrow={1}>
    {connectionError() ? (
      <ErrorView />
    ) : !isFinished() ? (
      <box justifyContent="center" alignItems="center" flexDirection="column">
        <ascii_font font="tiny" text="TTY Clock Timer" />
        <text attributes={TextAttributes.BOLD}>{formatRemaining(remainingSeconds())}</text>
        <text attributes={TextAttributes.DIM}>Status: {timerStatus()}</text>
      </box>
    ) : (
      <FinishedView />
    )}
  </box>
));
