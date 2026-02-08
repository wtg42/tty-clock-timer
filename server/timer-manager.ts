// Timer process management
import { Subprocess } from "bun";
import type { IPCMessage } from "./types";
import { updateTimerState, resetTimerState, sseClients } from "./state";
import { broadcastSSE } from "./sse";
import * as path from "path";
import * as fs from "fs";

let coreProcess: Subprocess | null = null;

// Find Core binary path (handles different working directories)
function findCoreBinaryPath(): string {
  const binaryName = "tty_clock_timer";
  const possiblePaths = [
    `./core/zig-out/bin/${binaryName}`,     // From project root
    `./zig-out/bin/${binaryName}`,          // From project root (if zig-out is there)
    `../core/zig-out/bin/${binaryName}`,    // From server/
    `../../core/zig-out/bin/${binaryName}`, // From server/dist/
    path.join(process.cwd(), `core/zig-out/bin/${binaryName}`),
    path.join(process.cwd(), `zig-out/bin/${binaryName}`),
  ];

  for (const binPath of possiblePaths) {
    const resolved = path.resolve(binPath);
    if (fs.existsSync(resolved)) {
      return resolved;
    }
  }

  throw new Error(
    `Core binary not found. Tried paths:\n${possiblePaths.join("\n")}\nCurrent directory: ${process.cwd()}`
  );
}

// Spawn Core process
export async function spawnCoreProcess(): Promise<void> {
  if (coreProcess) {
    console.warn("Core process already running");
    return;
  }

  const coreBinaryPath = findCoreBinaryPath();
  console.log(`Spawning Core process: ${coreBinaryPath}`);

  try {
    coreProcess = Bun.spawn({
      cmd: [coreBinaryPath],
      stdin: "pipe",
      stdout: "pipe",
      stderr: "inherit",
    });

    console.log(`Core process spawned with PID: ${coreProcess.pid}`);

    // Start reading stdout
    readCoreStdout();

    // Monitor process exit
    monitorCoreProcess();
  } catch (error) {
    console.error("Failed to spawn Core process:", error);
    throw error;
  }
}

// Read Core stdout and parse JSON messages
async function readCoreStdout(): Promise<void> {
  if (!coreProcess || !coreProcess.stdout) {
    return;
  }

  const reader = coreProcess.stdout.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      buffer = lines.pop() || ""; // Keep incomplete line in buffer

      for (const line of lines) {
        if (line.trim()) {
          handleCoreMessage(line);
        }
      }
    }
  } catch (error) {
    console.error("Error reading Core stdout:", error);
  } finally {
    reader.releaseLock();
  }
}

// Handle incoming IPC message from Core
function handleCoreMessage(line: string): void {
  try {
    const message: IPCMessage = JSON.parse(line);

    switch (message.type) {
      case "update_timer":
        if (
          message.remaining_seconds !== undefined &&
          message.total_duration !== undefined &&
          message.status
        ) {
          updateTimerState({
            remaining_seconds: message.remaining_seconds,
            total_duration: message.total_duration,
            status: message.status,
          });
          broadcastSSE({
            type: "update_timer",
            remaining_seconds: message.remaining_seconds,
            total_duration: message.total_duration,
            status: message.status,
          });
        }
        break;

      case "timer_finished":
        updateTimerState({ status: "finished" });
        broadcastSSE({ type: "timer_finished" });
        break;

      case "exit":
        console.log("Core process requested exit");
        break;

      default:
        console.warn("Unknown message type from Core:", message);
    }
  } catch (error) {
    console.error("Failed to parse Core message:", line, error);
  }
}

// Send command to Core process
export function sendCommandToCore(command: Record<string, any>): void {
  if (!coreProcess || !coreProcess.stdin) {
    console.error("Core process not running, cannot send command");
    return;
  }

  const json = JSON.stringify(command) + "\n";
  coreProcess.stdin.write(json);
}

// Monitor Core process for crashes
async function monitorCoreProcess(): Promise<void> {
  if (!coreProcess) return;

  try {
    const exitCode = await coreProcess.exited;

    if (exitCode !== 0) {
      console.error(`Core process crashed with exit code: ${exitCode}`);

      // Broadcast error to all SSE clients
      broadcastSSE({
        type: "error",
        message: `Core process crashed with exit code ${exitCode}`,
      });
    } else {
      console.log("Core process exited normally");
    }

    coreProcess = null;
  } catch (error) {
    console.error("Error monitoring Core process:", error);
  }
}

// Terminate Core process
export async function terminateCoreProcess(timeout: number = 5000): Promise<void> {
  if (!coreProcess) {
    return;
  }

  console.log("Terminating Core process...");

  // Send exit command
  sendCommandToCore({ cmd: "exit" });

  // Wait for graceful exit or timeout
  const timeoutPromise = new Promise<void>((resolve) => {
    setTimeout(() => {
      if (coreProcess) {
        console.log("Core process did not exit gracefully, force killing...");
        coreProcess.kill();
      }
      resolve();
    }, timeout);
  });

  const exitPromise = coreProcess.exited.then(() => {
    console.log("Core process exited gracefully");
  });

  await Promise.race([exitPromise, timeoutPromise]);
  coreProcess = null;
}
