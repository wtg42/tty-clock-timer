/**
 * @fileoverview Sound playback helper.
 */

export const playSound = (player: string, file: string): void => {
  try {
    Bun.spawn([player, file], {
      stdin: "ignore",
      stdout: "ignore",
      stderr: "ignore",
    });
  } catch {
    // Silent by design.
  }
};
