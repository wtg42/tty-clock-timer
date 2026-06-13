import { afterEach, describe, expect, test } from "bun:test";

import { playSound } from "./sound.ts";

const originalSpawn = Bun.spawn;

afterEach(() => {
  (Bun as unknown as { spawn: typeof Bun.spawn }).spawn = originalSpawn;
});

describe("sound/playSound", () => {
  test("spawns configured player fire-and-forget", () => {
    const calls: Array<{ command: string[]; options: Record<string, string> }> = [];
    (Bun as unknown as { spawn: typeof Bun.spawn }).spawn = ((command: string[], options: Record<string, string>) => {
      calls.push({ command, options });
      return {};
    }) as typeof Bun.spawn;

    playSound("/usr/bin/afplay", "/tmp/ding.wav");

    expect(calls).toEqual([
      {
        command: ["/usr/bin/afplay", "/tmp/ding.wav"],
        options: {
          stdin: "ignore",
          stdout: "ignore",
          stderr: "ignore",
        },
      },
    ]);
  });

  test("silently ignores spawn failures", () => {
    (Bun as unknown as { spawn: typeof Bun.spawn }).spawn = (() => {
      throw new Error("missing player");
    }) as typeof Bun.spawn;

    expect(() => playSound("/missing/player", "/tmp/ding.wav")).not.toThrow();
  });
});
