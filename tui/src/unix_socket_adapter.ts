import net from "node:net";

import {
  type CommandMessage,
  type CommandName,
  type CommandResponse,
  type CoreEvent,
  isCommandResultMessage,
  isCoreEvent,
} from "./protocol.ts";

type PendingResolver = {
  command: CommandName;
  resolve: (value: CommandResponse) => void;
  reject: (reason?: unknown) => void;
};

export class UnixSocketAdapter {
  private readonly socketPath: string;
  private socket: net.Socket | null = null;
  private connectInFlight: Promise<void> | null = null;
  private readBuffer = "";
  private commandCounter = 0;
  private readonly pending = new Map<string, PendingResolver>();
  private readonly listeners = new Set<(event: CoreEvent) => void>();

  constructor(socketPath: string) {
    this.socketPath = socketPath;
  }

  async connect(): Promise<void> {
    if (this.socket) return;
    if (this.connectInFlight) {
      return this.connectInFlight;
    }

    this.connectInFlight = new Promise<void>((resolve, reject) => {
      const socket = net.createConnection({ path: this.socketPath });
      const timeout = setTimeout(() => {
        socket.destroy();
        reject(new Error(`Timed out connecting unix socket at ${this.socketPath}`));
      }, 3000);

      const onError = (error: unknown) => {
        clearTimeout(timeout);
        reject(
          new Error(
            `Failed to connect unix socket at ${this.socketPath}: ${(error as Error).message}`,
          ),
        );
      };

      socket.once("error", onError);

      socket.once("connect", () => {
        clearTimeout(timeout);
        socket.off("error", onError);
        this.socket = socket;
        socket.setEncoding("utf8");
        socket.on("data", (chunk: string | Buffer) => {
          this.handleChunk(typeof chunk === "string" ? chunk : chunk.toString("utf8"));
        });
        socket.on("close", () => {
          this.socket = null;
          this.readBuffer = "";
          this.rejectAllPending(new Error("Unix socket closed"));
        });
        socket.on("error", (error) => {
          this.rejectAllPending(error);
        });
        resolve();
      });
    });

    try {
      await this.connectInFlight;
    } finally {
      this.connectInFlight = null;
    }
  }

  async disconnect(): Promise<void> {
    const socket = this.socket;
    this.socket = null;
    this.readBuffer = "";

    if (!socket) {
      this.rejectAllPending(new Error("Unix socket closed"));
      return;
    }

    await new Promise<void>((resolve) => {
      let done = false;
      const finish = () => {
        if (done) return;
        done = true;
        resolve();
      };

      socket.once("close", finish);
      socket.end();

      const forceTimeout = setTimeout(() => {
        if (!socket.destroyed) {
          socket.destroy();
        }
        finish();
      }, 200);
      forceTimeout.unref();
    });

    this.rejectAllPending(new Error("Unix socket closed"));
  }

  onEvent(listener: (event: CoreEvent) => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  async sendCommand(command: CommandName): Promise<CommandResponse> {
    if (!this.socket) {
      return { ok: false, command, error: "socket_not_connected" };
    }

    const id = `${Date.now()}-${this.commandCounter++}`;
    const request: CommandMessage = { type: "command", id, command };

    return new Promise<CommandResponse>((resolve, reject) => {
      this.pending.set(id, { command, resolve, reject });

      this.socket?.write(`${JSON.stringify(request)}\n`, (error) => {
        if (!error) return;
        this.pending.delete(id);
        reject(error);
      });
    });
  }

  private handleChunk(chunk: string): void {
    this.readBuffer += chunk;

    let newlineIndex = this.readBuffer.indexOf("\n");
    while (newlineIndex >= 0) {
      const line = this.readBuffer.slice(0, newlineIndex).trim();
      this.readBuffer = this.readBuffer.slice(newlineIndex + 1);
      newlineIndex = this.readBuffer.indexOf("\n");

      if (!line) continue;

      let payload: unknown;
      try {
        payload = JSON.parse(line);
      } catch {
        continue;
      }

      if (isCommandResultMessage(payload)) {
        const pending = this.pending.get(payload.id);
        if (!pending) continue;

        this.pending.delete(payload.id);
        if (payload.success) {
          pending.resolve({ ok: true, command: pending.command });
        } else {
          pending.resolve({
            ok: false,
            command: pending.command,
            error: payload.error ?? "unknown_error",
          });
        }
        continue;
      }

      if (!isCoreEvent(payload)) continue;
      for (const listener of this.listeners) {
        listener(payload);
      }
    }
  }

  private rejectAllPending(reason: unknown): void {
    for (const [, pending] of this.pending) {
      pending.reject(reason);
    }
    this.pending.clear();
  }
}
