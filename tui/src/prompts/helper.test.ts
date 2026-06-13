import { describe, expect, test } from "bun:test";

import { formatDurationLabel, parseDurationSeconds, runPromptCommand } from "./helper";

const canceled = Symbol("canceled");

const createPromptStubs = (overrides: {
  select?: (options: any) => unknown;
  multiselect?: (options: any) => unknown;
  text?: (options: any) => unknown;
} = {}) => ({
  select: async <T>(options: any) => (overrides.select?.(options) ?? canceled) as T | symbol,
  multiselect: async <T>(options: any) => (overrides.multiselect?.(options) ?? canceled) as T[] | symbol,
  text: async (options: any) => (overrides.text?.(options) ?? canceled) as string | symbol,
});

describe("prompt helper utilities", () => {
  test("formatDurationLabel formats mm:ss labels", () => {
    expect(formatDurationLabel(90)).toBe("01:30 (90s)");
    expect(formatDurationLabel(5)).toBe("00:05 (5s)");
  });

  test("parseDurationSeconds accepts strings and arrays", () => {
    expect(parseDurationSeconds("120")).toEqual([120]);
    expect(parseDurationSeconds(["60", "90", "0", "bad"])).toEqual([60, 90]);
    expect(parseDurationSeconds(undefined)).toEqual([]);
  });
});

describe("prompt helper command runner", () => {
  test("history-select submits selected duration", async () => {
    const seenLabels: string[] = [];
    const prompts = createPromptStubs({
      select: (options) => {
        seenLabels.push(...options.options.map((option: { label: string }) => option.label));
        return 90;
      },
    });

    const result = await runPromptCommand(
      ["history-select", "--duration-seconds", "60", "--duration-seconds", "90"],
      prompts,
    );

    expect(result).toEqual({ status: "submitted", duration_seconds: 90 });
    expect(seenLabels).toEqual(["01:00 (60s)", "01:30 (90s)"]);
  });

  test("history-select returns error when durations are missing", async () => {
    const result = await runPromptCommand(["history-select"], createPromptStubs());

    expect(result).toEqual({ status: "error", code: "missing_durations" });
  });

  test("history-delete submits selected labels", async () => {
    const result = await runPromptCommand(
      ["history-delete", "--duration-seconds", "60", "--duration-seconds", "120"],
      createPromptStubs({
        multiselect: (options) => [options.options[1].value],
      }),
    );

    expect(result).toEqual({
      status: "submitted",
      selected_labels: ["02:00 (120s)"],
    });
  });

  test("history-delete maps empty selection to canceled", async () => {
    const result = await runPromptCommand(
      ["history-delete", "--duration-seconds", "60"],
      createPromptStubs({
        multiselect: () => [],
      }),
    );

    expect(result).toEqual({ status: "canceled" });
  });

  test("setup-sound submits selected player and trimmed file", async () => {
    let textPromptCount = 0;
    const result = await runPromptCommand(
      ["setup-sound", "--player", "/usr/bin/afplay"],
      createPromptStubs({
        select: () => " /usr/bin/afplay ",
        text: () => {
          textPromptCount += 1;
          return " /tmp/ding.wav ";
        },
      }),
    );

    expect(result).toEqual({
      status: "submitted",
      player: "/usr/bin/afplay",
      file: "/tmp/ding.wav",
    });
    expect(textPromptCount).toBe(1);
  });

  test("setup-sound asks for player path when no players are provided", async () => {
    const messages: string[] = [];
    const result = await runPromptCommand(
      ["setup-sound"],
      createPromptStubs({
        text: (options) => {
          messages.push(options.message);
          return messages.length === 1 ? "/usr/bin/paplay" : "/tmp/ding.wav";
        },
      }),
    );

    expect(result).toEqual({
      status: "submitted",
      player: "/usr/bin/paplay",
      file: "/tmp/ding.wav",
    });
    expect(messages).toEqual(["Enter full player path", "Enter sound file path"]);
  });

  test("setup-sound maps prompt cancellation to canceled", async () => {
    const result = await runPromptCommand(
      ["setup-sound", "--player", "/usr/bin/afplay"],
      createPromptStubs({
        select: () => canceled,
      }),
    );

    expect(result).toEqual({ status: "canceled" });
  });

  test("invalid command throws a stable error code", async () => {
    await expect(runPromptCommand(["unknown"], createPromptStubs())).rejects.toThrow("invalid_command");
  });
});
