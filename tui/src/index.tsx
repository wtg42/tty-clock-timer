import { TextAttributes } from "@opentui/core";
import { render } from "@opentui/solid";
import { createSignal } from "solid-js";

type TimerUpdateMessage = {
  type: "update_timer";
  remaining_seconds: number;
  total_duration: number;
  status: string;
};

const [remainingSeconds, setRemainingSeconds] = createSignal<number | null>(null);
const [timerStatus, setTimerStatus] = createSignal<string>("idle");

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

// OpenTUI 入口渲染
// 步驟：
// 1. 建立版面容器
// 2. 放置 ASCII 標題與計時資訊
render(() => (
  <box alignItems="center" justifyContent="center" flexGrow={1}>
    <box justifyContent="center" alignItems="center" flexDirection="column">
      <ascii_font font="tiny" text="TTY Clock Timer" />
      <text attributes={TextAttributes.BOLD}>{formatRemaining(remainingSeconds())}</text>
      <text attributes={TextAttributes.DIM}>Status: {timerStatus()}</text>
    </box>
  </box>
));
