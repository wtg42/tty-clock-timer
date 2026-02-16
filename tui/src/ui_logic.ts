import type { CommandName } from "./protocol.ts";

export type IssuedCommandRecord = {
  command: CommandName;
  at: number;
};

export const formatRemaining = (seconds: number | null): string => {
  if (seconds === null) return "--:--";
  const minutes = Math.floor(seconds / 60);
  const remaining = seconds % 60;
  return `${minutes.toString().padStart(2, "0")}:${remaining.toString().padStart(2, "0")}`;
};

export const commandFromKey = (key: string): CommandName | null => {
  switch (key) {
    case "p":
      return "pause";
    case "r":
      return "resume";
    case "s":
      return "reset";
    case "q":
      return "quit";
    default:
      return null;
  }
};

export const shouldSkipByStatus = (status: string, command: CommandName): boolean => {
  if (command === "pause") return status !== "running";
  if (command === "resume") return status !== "paused";
  return false;
};

export const shouldSkipByDedup = (
  previous: IssuedCommandRecord | null,
  command: CommandName,
  now: number,
  dedupWindowMs: number,
): { skip: boolean; next: IssuedCommandRecord } => {
  if (previous && previous.command === command && now - previous.at < dedupWindowMs) {
    return { skip: true, next: previous };
  }

  return {
    skip: false,
    next: { command, at: now },
  };
};
