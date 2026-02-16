import { describe, expect, test } from "bun:test";

import { isCommandResultMessage, isCoreEvent } from "./protocol.ts";

describe("protocol/isCoreEvent", () => {
  test("isCoreEvent - normal update_timer payload", () => {
    expect(
      isCoreEvent({
        type: "update_timer",
        remaining_seconds: 30,
        total_duration: 60,
        status: "running",
      }),
    ).toBe(true);
  });

  test("isCoreEvent - edge update_timer missing field", () => {
    expect(
      isCoreEvent({
        type: "update_timer",
        remaining_seconds: 30,
        total_duration: 60,
      }),
    ).toBe(false);
  });

  test("isCoreEvent - normal exit payload", () => {
    expect(isCoreEvent({ type: "exit" })).toBe(true);
  });

  test("isCoreEvent - edge timer_finished invalid total_duration type", () => {
    expect(
      isCoreEvent({
        type: "timer_finished",
        total_duration: "60",
      }),
    ).toBe(false);
  });
});

describe("protocol/isCommandResultMessage", () => {
  test("isCommandResultMessage - normal success payload", () => {
    expect(
      isCommandResultMessage({
        type: "command_result",
        id: "cmd-1",
        success: true,
        error: null,
      }),
    ).toBe(true);
  });

  test("isCommandResultMessage - edge invalid error type", () => {
    expect(
      isCommandResultMessage({
        type: "command_result",
        id: "cmd-1",
        success: false,
        error: 500,
      }),
    ).toBe(false);
  });
});
