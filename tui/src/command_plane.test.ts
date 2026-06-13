import { describe, expect, test } from "bun:test";

import { createCommandPlane } from "./command_plane.ts";

describe("command_plane/createCommandPlane", () => {
  test("execute returns successful command response", async () => {
    const { execute } = createCommandPlane(async (command) => ({
      ok: true,
      command,
    }));

    await expect(execute("pause")).resolves.toEqual({
      ok: true,
      command: "pause",
    });
  });

  test("app rejects unsupported command names", async () => {
    const { app } = createCommandPlane(async (command) => ({
      ok: true,
      command,
    }));

    const response = await app.request("http://local/commands/snooze", {
      method: "POST",
    });

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toEqual({
      ok: false,
      command: "snooze",
      error: "unsupported_command",
    });
  });

  test("app maps command failure to conflict response", async () => {
    const { app } = createCommandPlane(async (command) => ({
      ok: false,
      command,
      error: "invalid_state",
    }));

    const response = await app.request("http://local/commands/pause", {
      method: "POST",
    });

    expect(response.status).toBe(409);
    await expect(response.json()).resolves.toEqual({
      ok: false,
      command: "pause",
      error: "invalid_state",
    });
  });

  test("app maps thrown errors to failed command response", async () => {
    const { app } = createCommandPlane(async () => {
      throw new Error("socket_closed");
    });

    const response = await app.request("http://local/commands/quit", {
      method: "POST",
    });

    expect(response.status).toBe(500);
    await expect(response.json()).resolves.toEqual({
      ok: false,
      command: "quit",
      error: "socket_closed",
    });
  });
});
