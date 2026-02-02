import { TextAttributes } from "@opentui/core";
import { render } from "@opentui/solid";
import { createSignal, onMount } from "solid-js";
import { useTimeline } from "@opentui/solid";

type TimerUpdateMessage = {
  type: "update_timer";
  remaining_seconds: number;
  total_duration: number;
  status: string;
};

type TimerFinishedMessage = {
  type: "timer_finished";
  total_duration: number;
};

const [remainingSeconds, setRemainingSeconds] = createSignal<number | null>(null);
const [timerStatus, setTimerStatus] = createSignal<string>("idle");
const [isFinished, setIsFinished] = createSignal<boolean>(false);

const isTimerUpdateMessage = (value: unknown): value is TimerUpdateMessage => {
  if (!value || typeof value !== "object") return false;
  const record = value as Record<string, unknown>;
  return (
    record.type === "update_timer" &&
    typeof record.remaining_seconds === "number" &&
    typeof record.total_duration === "number" &&
    typeof record.status === "string"
  );
};

const isTimerFinishedMessage = (value: unknown): value is TimerFinishedMessage => {
  if (!value || typeof value !== "object") return false;
  const record = value as Record<string, unknown>;
  return (
    record.type === "timer_finished" &&
    typeof record.total_duration === "number"
  );
};

const formatRemaining = (seconds: number | null) => {
  if (seconds === null) return "--:--";
  const minutes = Math.floor(seconds / 60);
  const remaining = seconds % 60;
  return `${minutes.toString().padStart(2, "0")}:${remaining.toString().padStart(2, "0")}`;
};

const handleLine = (line: string) => {
  const trimmed = line.trim();
  if (!trimmed) return;
  let parsed: unknown;
  try {
    parsed = JSON.parse(trimmed);
  } catch {
    return;
  }
  if (isTimerUpdateMessage(parsed)) {
    setRemainingSeconds(parsed.remaining_seconds);
    setTimerStatus(parsed.status);
  } else if (isTimerFinishedMessage(parsed)) {
    setIsFinished(true);
  }
};

let stdinBuffer = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  stdinBuffer += chunk;
  let newlineIndex = stdinBuffer.indexOf("\n");
  while (newlineIndex >= 0) {
    const line = stdinBuffer.slice(0, newlineIndex);
    stdinBuffer = stdinBuffer.slice(newlineIndex + 1);
    handleLine(line);
    newlineIndex = stdinBuffer.indexOf("\n");
  }
});

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

// OpenTUI 入口渲染
// 步驟：
// 1. 建立版面容器
// 2. 根據完成狀態顯示不同內容
render(() => (
  <box alignItems="center" justifyContent="center" flexGrow={1}>
    {!isFinished() ? (
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
