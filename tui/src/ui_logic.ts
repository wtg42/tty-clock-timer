/**
 * @fileoverview Pure UI helpers for input mapping and command throttling.
 *
 * This module is side-effect free and designed to be easy to test.
 */
import type { CommandName } from "./protocol.ts";

export type IssuedCommandRecord = {
  command: CommandName;
  at: number;
};

/**
 * Formats remaining time in `MM:SS` form.
 */
export const formatRemaining = (seconds: number | null): string => {
  if (seconds === null) return "--:--";
  const minutes = Math.floor(seconds / 60);
  const remaining = seconds % 60;
  return `${minutes.toString().padStart(2, "0")}:${remaining.toString().padStart(2, "0")}`;
};

/**
 * Maps keyboard keys to supported timer commands.
 */
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

/**
 * Checks whether a command should be skipped by current timer status.
 */
export const shouldSkipByStatus = (status: string, command: CommandName): boolean => {
  if (command === "pause") return status !== "running";
  if (command === "resume") return status !== "paused";
  if (command === "reset") return false; // reset always allowed
  return false;
};

/**
 * Deduplicates repeated commands within a time window.
 */
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
