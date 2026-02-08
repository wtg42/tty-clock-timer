// Type definitions for timer state and messages

export type TimerStatus = "idle" | "running" | "paused" | "finished";

export interface TimerState {
  status: TimerStatus;
  remaining_seconds: number;
  total_duration: number;
  elapsed_seconds: number;
}

export interface IPCMessage {
  type: "update_timer" | "timer_finished" | "exit" | "keyboard_input";
  remaining_seconds?: number;
  total_duration?: number;
  status?: string;
  key?: string;
}

export interface SSEClient {
  controller: ReadableStreamDefaultController;
  id: string;
}
