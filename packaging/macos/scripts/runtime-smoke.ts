import net from "node:net";
import { join } from "node:path";
import { dlopen } from "bun:ffi";

const socketFlag = process.argv.indexOf("--socket-path");
const socketPath = socketFlag >= 0 ? process.argv[socketFlag + 1] : undefined;
const runtimeRoot = process.env.TTC_MACOS_RUNTIME_ROOT;

if (!socketPath) throw new Error("missing --socket-path");
if (!runtimeRoot) throw new Error("missing TTC_MACOS_RUNTIME_ROOT");

const shimPath = join(
  runtimeRoot,
  "lib/tty-clock-timer/tui/node_modules/@opentui/core-darwin-arm64/index.ts",
);
const shimSource = await Bun.file(shimPath).text();
if (!shimSource.includes("libopentui.dylib")) {
  throw new Error("Darwin shim does not reference libopentui.dylib");
}
const nativeLibraryPath = join(runtimeRoot, "lib/tty-clock-timer/tui/libopentui.dylib");
const library = dlopen(nativeLibraryPath, {
  YGConfigGetDefault: { args: [], returns: "ptr" },
});
if (!library.symbols.YGConfigGetDefault()) {
  throw new Error("OpenTUI dylib returned a null default Yoga config");
}
library.close();

const socket = net.createConnection(socketPath);
let buffer = "";

const timer = setTimeout(() => {
  console.error("[macos-smoke] timeout waiting for controlled quit");
  process.exit(1);
}, 8_000);

socket.on("connect", () => {
  socket.write(`${JSON.stringify({ type: "command", id: "macos-smoke-quit", command: "quit" })}\n`);
});

socket.on("error", (error) => {
  console.error(`[macos-smoke] socket error: ${error.message}`);
  process.exit(1);
});

socket.on("data", (chunk) => {
  buffer += chunk.toString("utf8");
  while (buffer.includes("\n")) {
    const newline = buffer.indexOf("\n");
    const line = buffer.slice(0, newline).trim();
    buffer = buffer.slice(newline + 1);
    if (!line) continue;
    const message = JSON.parse(line);
    if (message.type === "command_result" && message.id === "macos-smoke-quit") {
      if (!message.success) throw new Error(`quit failed: ${message.error ?? "unknown"}`);
      clearTimeout(timer);
      console.log("[macos-smoke] dylib load, socket IPC, and controlled quit passed");
      socket.end();
      process.exit(0);
    }
  }
});
