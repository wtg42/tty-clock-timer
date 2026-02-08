// Global timer state management
import type { TimerState, SSEClient } from "./types";

// Global timer state (shared across all clients)
export const timerState: TimerState = {
  status: "idle",
  remaining_seconds: 0,
  total_duration: 0,
  elapsed_seconds: 0,
};

// Set of active SSE connections
export const sseClients: Set<SSEClient> = new Set();

// Update timer state from Core process updates
export function updateTimerState(update: {
  remaining_seconds?: number;
  total_duration?: number;
  status?: string;
}) {
  if (update.remaining_seconds !== undefined) {
    timerState.remaining_seconds = update.remaining_seconds;
  }
  if (update.total_duration !== undefined) {
    timerState.total_duration = update.total_duration;
    timerState.elapsed_seconds = update.total_duration - (update.remaining_seconds || 0);
  }
  if (update.status) {
    timerState.status = update.status as TimerState["status"];
  }
}

// Reset timer state to idle
export function resetTimerState() {
  timerState.status = "idle";
  timerState.remaining_seconds = 0;
  timerState.total_duration = 0;
  timerState.elapsed_seconds = 0;
}
