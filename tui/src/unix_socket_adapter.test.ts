import { afterEach, describe, expect, test } from "bun:test";
import { EventEmitter } from "node:events";
import net from "node:net";

import type { CommandMessage } from "./protocol.ts";
import { UnixSocketAdapter } from "./unix_socket_adapter.ts";

class FakeSocket extends EventEmitter {
  destroyed = false;
  writes: string[] = [];

  setEncoding(): this {
    return this;
  }

  write(data: string, callback?: (error?: Error) => void): boolean {
    this.writes.push(data);
    callback?.();
    return true;
  }

  end(): this {
    queueMicrotask(() => this.emit("close"));
    return this;
  }

  destroy(): this {
    this.destroyed = true;
    queueMicrotask(() => this.emit("close"));
    return this;
  }
}

const originalCreateConnection = net.createConnection;

afterEach(() => {
  (net as unknown as { createConnection: typeof net.createConnection }).createConnection = originalCreateConnection;
});

const connectWithFakeSocket = (socket: FakeSocket) => {
  (net as unknown as { createConnection: typeof net.createConnection }).createConnection = (() => {
    queueMicrotask(() => socket.emit("connect"));
    return socket;
  }) as typeof net.createConnection;
};

const parseWrittenCommand = (socket: FakeSocket): CommandMessage => {
  const line = socket.writes.at(-1)?.trim();
  if (!line) throw new Error("missing command write");
  return JSON.parse(line) as CommandMessage;
};

describe("unix_socket_adapter/UnixSocketAdapter", () => {
  test("sendCommand returns not connected before connect", async () => {
    const adapter = new UnixSocketAdapter("/tmp/tty-clock-timer-not-connected.sock");

    await expect(adapter.sendCommand("pause")).resolves.toEqual({
      ok: false,
      command: "pause",
      error: "socket_not_connected",
    });
  });

  test("sendCommand writes command messages and resolves command results", async () => {
    const socket = new FakeSocket();
    connectWithFakeSocket(socket);
    const adapter = new UnixSocketAdapter("/tmp/tty-clock-timer.sock");

    await adapter.connect();

    const pauseResult = adapter.sendCommand("pause");
    const pauseMessage = parseWrittenCommand(socket);
    socket.emit("data", `${JSON.stringify({
      type: "command_result",
      id: pauseMessage.id,
      success: true,
      error: null,
    })}\n`);

    await expect(pauseResult).resolves.toEqual({
      ok: true,
      command: "pause",
    });

    const resumeResult = adapter.sendCommand("resume");
    const resumeMessage = parseWrittenCommand(socket);
    socket.emit("data", `${JSON.stringify({
      type: "command_result",
      id: resumeMessage.id,
      success: false,
      error: "invalid_state",
    })}\n`);

    await expect(resumeResult).resolves.toEqual({
      ok: false,
      command: "resume",
      error: "invalid_state",
    });
    expect(socket.writes.map((line) => JSON.parse(line).command)).toEqual(["pause", "resume"]);

    await adapter.disconnect();
  });

  test("forwards valid events and ignores invalid frames", async () => {
    const socket = new FakeSocket();
    connectWithFakeSocket(socket);
    const adapter = new UnixSocketAdapter("/tmp/tty-clock-timer.sock");
    const events: unknown[] = [];
    adapter.onEvent((event) => events.push(event));

    await adapter.connect();

    socket.emit("data", "not-json\n");
    socket.emit("data", `${JSON.stringify({ type: "unknown" })}\n`);
    socket.emit("data", `${JSON.stringify({
      type: "update_timer",
      remaining_seconds: 30,
      total_duration: 60,
      status: "running",
      eta_epoch_seconds: 1_800,
    })}\n`);

    expect(events).toEqual([
      {
        type: "update_timer",
        remaining_seconds: 30,
        total_duration: 60,
        status: "running",
        eta_epoch_seconds: 1_800,
      },
    ]);

    await adapter.disconnect();
  });
});
