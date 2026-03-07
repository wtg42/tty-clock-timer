import { parse } from "@bomb.sh/args";
import { multiselect, select, text } from "@clack/prompts";

type SubmittedResult =
  | { status: "submitted"; duration_seconds: number }
  | { status: "submitted"; selected_labels: string[] }
  | { status: "submitted"; player: string; file: string };

type CanceledResult = { status: "canceled" };
type ErrorResult = { status: "error"; code: string };
type PromptResult = SubmittedResult | CanceledResult | ErrorResult;

type CommandName = "history-select" | "history-delete" | "setup-sound";

const promptIo = {
  input: process.stdin,
  output: process.stderr,
  withGuide: false,
};

const isPromptCancel = (value: unknown): value is symbol => typeof value === "symbol";

export const formatDurationLabel = (durationSeconds: number): string => {
  const minutes = Math.floor(durationSeconds / 60);
  const seconds = durationSeconds % 60;
  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")} (${durationSeconds}s)`;
};

const writeStdout = (result: PromptResult): never => {
  process.stdout.write(`${JSON.stringify(result)}\n`);
  process.exit(result.status === "error" ? 1 : 0);
};

const readScalarArray = (value: unknown): Array<string | number> => {
  if (Array.isArray(value)) {
    return value.filter((item): item is string | number => typeof item === "string" || typeof item === "number");
  }
  if (typeof value === "string" || typeof value === "number") {
    return [value];
  }
  return [];
};

export const parseDurationSeconds = (value: unknown): number[] => {
  return readScalarArray(value)
    .map((item) => typeof item === "number" ? item : Number.parseInt(item, 10))
    .filter((item) => Number.isFinite(item) && item > 0);
};

const readStringArray = (value: unknown): string[] => {
  return readScalarArray(value)
    .map((item) => String(item))
    .filter((item) => item.length > 0);
};

const requireCommand = (value: unknown): CommandName => {
  if (
    value === "history-select" ||
    value === "history-delete" ||
    value === "setup-sound"
  ) {
    return value;
  }
  throw new Error("invalid_command");
};

const runHistorySelect = async (durations: number[]): Promise<PromptResult> => {
  if (durations.length === 0) {
    return { status: "error", code: "missing_durations" };
  }

  const selected = await select<number>({
    ...promptIo,
    message: "Select timer duration",
    options: durations.map((durationSeconds) => ({
      value: durationSeconds,
      label: formatDurationLabel(durationSeconds),
    })),
  });

  if (isPromptCancel(selected)) {
    return { status: "canceled" };
  }

  return { status: "submitted", duration_seconds: selected };
};

const runHistoryDelete = async (durations: number[]): Promise<PromptResult> => {
  if (durations.length === 0) {
    return { status: "error", code: "missing_durations" };
  }

  const labels = durations.map(formatDurationLabel);
  const selected = await multiselect<string>({
    ...promptIo,
    message: "Select durations to delete",
    options: labels.map((label) => ({ value: label, label })),
  });

  if (isPromptCancel(selected)) {
    return { status: "canceled" };
  }

  if (selected.length === 0) {
    return { status: "canceled" };
  }

  return { status: "submitted", selected_labels: selected };
};

const runSetupSound = async (players: string[]): Promise<PromptResult> => {
  let player: string | symbol;
  if (players.length > 0) {
    player = await select<string>({
      ...promptIo,
      message: "Select a sound player",
      options: players.map((item) => ({ value: item, label: item })),
    });
  } else {
    player = await text({
      ...promptIo,
      message: "Enter full player path",
      placeholder: "/usr/bin/paplay",
      validate: (value) => value && value.trim().length > 0 ? undefined : "Path is required",
    });
  }

  if (isPromptCancel(player)) {
    return { status: "canceled" };
  }

  const file = await text({
    ...promptIo,
    message: "Enter sound file path",
    placeholder: "/path/to/sound.wav",
    validate: (value) => value && value.trim().length > 0 ? undefined : "Path is required",
  });

  if (isPromptCancel(file)) {
    return { status: "canceled" };
  }

  return {
    status: "submitted",
    player: player.trim(),
    file: file.trim(),
  };
};

export const runPromptCommand = async (argv: string[]): Promise<PromptResult> => {
  const args = parse<Record<string, unknown>>(argv, {
    string: ["duration-seconds", "player"],
    array: ["duration-seconds", "player"],
  });

  const command = requireCommand(args._[0]);
  const durations = parseDurationSeconds(args["duration-seconds"]);
  const players = readStringArray(args.player);

  switch (command) {
    case "history-select":
      return runHistorySelect(durations);
    case "history-delete":
      return runHistoryDelete(durations);
    case "setup-sound":
      return runSetupSound(players);
  }
};

if (import.meta.main) {
  try {
    const result = await runPromptCommand(process.argv.slice(2));
    writeStdout(result);
  } catch (error) {
    const code = error instanceof Error ? error.message : "unexpected_error";
    writeStdout({ status: "error", code });
  }
}
