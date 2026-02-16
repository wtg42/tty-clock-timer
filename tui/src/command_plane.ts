/**
 * @fileoverview HTTP-like command plane for local command dispatch.
 *
 * This module wraps command execution behind a Hono app so the UI can use a
 * single request path (`/commands/:command`) and receive normalized
 * `CommandResponse` payloads.
 */
import { Hono } from "hono";

import type { CommandName, CommandResponse } from "./protocol.ts";

type CommandSender = (command: CommandName) => Promise<CommandResponse>;

/**
 * Creates an in-process command router and an execute helper.
 */
export const createCommandPlane = (sendCommand: CommandSender) => {
  const app = new Hono();

  app.post("/commands/:command", async (c) => {
    const command = c.req.param("command");
    if (!isCommandName(command)) {
      return c.json<CommandResponse>(
        { ok: false, command, error: "unsupported_command" },
        400,
      );
    }

    try {
      const result = await sendCommand(command);
      if (result.ok) {
        return c.json(result, 200);
      }
      return c.json(result, 409);
    } catch (error) {
      return c.json<CommandResponse>(
        {
          ok: false,
          command,
          error: error instanceof Error ? error.message : "command_failed",
        },
        500,
      );
    }
  });

  const execute = async (command: CommandName): Promise<CommandResponse> => {
    const response = await app.request(`http://local/commands/${command}`, {
      method: "POST",
    });
    return (await response.json()) as CommandResponse;
  };

  return { app, execute };
};

const isCommandName = (value: string): value is CommandName => {
  return value === "pause" || value === "resume" || value === "reset" || value === "quit";
};
