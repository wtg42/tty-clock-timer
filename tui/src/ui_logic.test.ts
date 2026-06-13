/**
 * @fileoverview Unit tests for pure UI logic helpers.
 */
import { describe, expect, test } from "bun:test";

import {
  commandFromKey,
  formatRemaining,
  shouldSkipByDedup,
  shouldSkipByStatus,
} from "./ui_logic.ts";

describe("ui_logic/formatRemaining", () => {
  test("formatRemaining - normal minutes and seconds", () => {
    expect(formatRemaining(65)).toBe("01:05");
  });

  test("formatRemaining - edge null input", () => {
    expect(formatRemaining(null)).toBe("--:--");
  });
});

describe("ui_logic/commandFromKey", () => {
  test("commandFromKey - normal mapped key", () => {
    expect(commandFromKey("p")).toBe("pause");
  });

  test("commandFromKey - maps all supported control keys", () => {
    expect(commandFromKey("r")).toBe("resume");
    expect(commandFromKey("s")).toBe("reset");
    expect(commandFromKey("q")).toBe("quit");
  });

  test("commandFromKey - edge unknown key", () => {
    expect(commandFromKey("x")).toBeNull();
  });
});

describe("ui_logic/shouldSkipByStatus", () => {
  test("shouldSkipByStatus - normal valid transition", () => {
    expect(shouldSkipByStatus("running", "pause")).toBe(false);
  });

  test("shouldSkipByStatus - edge invalid transition", () => {
    expect(shouldSkipByStatus("paused", "pause")).toBe(true);
  });

  test("shouldSkipByStatus - resume only runs while paused", () => {
    expect(shouldSkipByStatus("paused", "resume")).toBe(false);
    expect(shouldSkipByStatus("running", "resume")).toBe(true);
  });

  test("shouldSkipByStatus - reset and quit are not status-gated", () => {
    expect(shouldSkipByStatus("finished", "reset")).toBe(false);
    expect(shouldSkipByStatus("finished", "quit")).toBe(false);
  });
});

describe("ui_logic/shouldSkipByDedup", () => {
  test("shouldSkipByDedup - normal first command is not skipped", () => {
    const result = shouldSkipByDedup(null, "pause", 1_000, 250);
    expect(result.skip).toBe(false);
    expect(result.next).toEqual({ command: "pause", at: 1_000 });
  });

  test("shouldSkipByDedup - edge repeated command inside dedup window", () => {
    const previous = { command: "pause" as const, at: 1_000 };
    const result = shouldSkipByDedup(previous, "pause", 1_100, 250);
    expect(result.skip).toBe(true);
    expect(result.next).toBe(previous);
  });

  test("shouldSkipByDedup - allows repeated command at window boundary", () => {
    const previous = { command: "pause" as const, at: 1_000 };
    const result = shouldSkipByDedup(previous, "pause", 1_250, 250);
    expect(result.skip).toBe(false);
    expect(result.next).toEqual({ command: "pause", at: 1_250 });
  });

  test("shouldSkipByDedup - allows different command inside window", () => {
    const previous = { command: "pause" as const, at: 1_000 };
    const result = shouldSkipByDedup(previous, "quit", 1_100, 250);
    expect(result.skip).toBe(false);
    expect(result.next).toEqual({ command: "quit", at: 1_100 });
  });
});
