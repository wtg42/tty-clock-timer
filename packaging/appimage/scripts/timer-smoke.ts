import net from "node:net";

const parseSocketPath = (): string => {
  const flag = "--socket-path";
  const index = process.argv.findIndex((value) => value === flag);
  if (index >= 0 && process.argv[index + 1]) {
    return process.argv[index + 1] as string;
  }
  throw new Error("missing --socket-path");
};

const socket = net.createConnection(parseSocketPath());
let readBuffer = "";
let firstRemaining: number | null = null;
let observedDecrement = false;
let sentQuit = false;

const fail = (message: string): never => {
  console.error(`[timer-smoke] ${message}`);
  process.exit(1);
};

const sendQuit = () => {
  if (sentQuit) return;
  sentQuit = true;
  socket.write(`${JSON.stringify({ type: "command", id: "timer-smoke-quit", command: "quit" })}\n`);
};

socket.on("error", (error) => {
  fail(`socket error: ${error.message}`);
});

socket.on("data", (chunk) => {
  readBuffer += chunk.toString("utf8");

  while (true) {
    const newlineIndex = readBuffer.indexOf("\n");
    if (newlineIndex < 0) return;

    const line = readBuffer.slice(0, newlineIndex).trim();
    readBuffer = readBuffer.slice(newlineIndex + 1);
    if (!line) continue;

    let message: any;
    try {
      message = JSON.parse(line);
    } catch {
      continue;
    }

    if (message.type === "update_timer") {
      const remaining = Number(message.remaining_seconds);
      if (!Number.isFinite(remaining)) {
        fail("invalid remaining_seconds payload");
      }
      if (firstRemaining === null) {
        firstRemaining = remaining;
      } else if (remaining < firstRemaining) {
        observedDecrement = true;
        sendQuit();
      }
      continue;
    }

    if (message.type === "command_result" && message.id === "timer-smoke-quit") {
      if (!message.success) {
        fail(`quit command failed: ${message.error ?? "unknown"}`);
      }
      if (!observedDecrement) {
        fail("timer decrement was not observed before quit");
      }
      console.log("[timer-smoke] timer update flow passed");
      process.exit(0);
    }
  }
});

setTimeout(() => {
  fail("timeout waiting for timer updates");
}, 8000);
