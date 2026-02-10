export type CommandName = "pause" | "resume" | "reset" | "quit";

export type CoreEvent = TimerUpdateMessage | TimerFinishedMessage | ExitMessage;

export type TimerUpdateMessage = {
  type: "update_timer";
  remaining_seconds: number;
  total_duration: number;
  status: string;
};

export type TimerFinishedMessage = {
  type: "timer_finished";
  total_duration: number;
};

export type ExitMessage = {
  type: "exit";
};

export type CommandMessage = {
  type: "command";
  id: string;
  command: CommandName;
};

export type CommandResultMessage = {
  type: "command_result";
  id: string;
  success: boolean;
  error: string | null;
};

export type CommandResponse =
  | { ok: true; command: CommandName }
  | { ok: false; command: string; error: string };

export const isCoreEvent = (value: unknown): value is CoreEvent => {
  if (!value || typeof value !== "object") return false;
  const record = value as Record<string, unknown>;

  if (record.type === "update_timer") {
    return (
      typeof record.remaining_seconds === "number" &&
      typeof record.total_duration === "number" &&
      typeof record.status === "string"
    );
  }

  if (record.type === "timer_finished") {
    return typeof record.total_duration === "number";
  }

  if (record.type === "exit") {
    return true;
  }

  return false;
};

export const isCommandResultMessage = (
  value: unknown,
): value is CommandResultMessage => {
  if (!value || typeof value !== "object") return false;
  const record = value as Record<string, unknown>;

  return (
    record.type === "command_result" &&
    typeof record.id === "string" &&
    typeof record.success === "boolean" &&
    (record.error === null || typeof record.error === "string")
  );
};
