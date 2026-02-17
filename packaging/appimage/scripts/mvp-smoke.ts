import net from "node:net";

type CommandName = "pause" | "resume" | "reset" | "quit";

const parseSocketPath = (): string => {
  const flag = "--socket-path";
  const index = process.argv.findIndex((value) => value === flag);
  if (index >= 0 && process.argv[index + 1]) {
    return process.argv[index + 1] as string;
  }
  throw new Error("missing --socket-path");
};

const socketPath = parseSocketPath();
const commands: CommandName[] = ["pause", "resume", "reset", "quit"];
const idToCommand = new Map<string, CommandName>();

const socket = net.createConnection(socketPath);
let readBuffer = "";
let nextIndex = 0;
let completedQuit = false;

const sendNext = () => {
  if (nextIndex >= commands.length) return;
  const command = commands[nextIndex];
  nextIndex += 1;
  const id = `mvp-${command}-${nextIndex}`;
  idToCommand.set(id, command);
  socket.write(
    `${JSON.stringify({
      type: "command",
      id,
      command,
    })}\n`,
  );
};

const fail = (message: string): never => {
  console.error(`[mvp-smoke] ${message}`);
  process.exit(1);
};

socket.on("error", (error) => {
  fail(`socket error: ${error.message}`);
});

socket.on("connect", () => {
  sendNext();
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

    if (message.type !== "command_result") continue;
    const command = idToCommand.get(message.id as string);
    if (!command) continue;

    if (!message.success) {
      fail(`command '${command}' failed with error '${message.error ?? "unknown"}'`);
    }

    if (command === "quit") {
      completedQuit = true;
      socket.end();
      console.log("[mvp-smoke] pause/resume/reset/quit passed");
      process.exit(0);
    }

    sendNext();
  }
});

setTimeout(() => {
  if (!completedQuit) {
    fail("timeout waiting for command_result sequence");
  }
}, 8000);
