import { describe, expect, test } from "bun:test";

import { formatDurationLabel, parseDurationSeconds } from "./helper";

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
