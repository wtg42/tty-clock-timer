/**
 * @fileoverview Local timer view-state store.
 *
 * The store projects inbound core events into an immutable snapshot model used
 * by the UI layer, and provides a simple subscribe API.
 */
import type { CoreEvent } from "./protocol.ts";
import type { SoundConfig } from "./protocol.ts";

export type TimerViewState = {
  remainingSeconds: number | null;
  status: string;
  etaHhmm: string | null;
  isFinished: boolean;
  shouldExit: boolean;
  sound: SoundConfig | null;
};

const initialState: TimerViewState = {
  remainingSeconds: null,
  status: "connecting",
  etaHhmm: null,
  isFinished: false,
  shouldExit: false,
  sound: null,
};

/**
 * Creates an in-memory store that maps `CoreEvent` to `TimerViewState`.
 */
export const createTimerStore = () => {
  let state: TimerViewState = { ...initialState };
  const subscribers = new Set<(nextState: TimerViewState) => void>();

  const emit = () => {
    for (const subscriber of subscribers) {
      subscriber({ ...state });
    }
  };

  return {
    getState: () => ({ ...state }),

    subscribe: (subscriber: (nextState: TimerViewState) => void) => {
      subscribers.add(subscriber);
      return () => subscribers.delete(subscriber);
    },

    applyEvent: (event: CoreEvent) => {
      switch (event.type) {
        case "init":
          state = {
            ...state,
            sound: event.sound,
          };
          break;
        case "update_timer":
          state = {
            ...state,
            remainingSeconds: event.remaining_seconds,
            status: event.status,
            etaHhmm: event.eta_hhmm,
            isFinished: event.status === "finished",
          };
          break;
        case "timer_finished":
          state = {
            ...state,
            remainingSeconds: 0,
            status: "finished",
            isFinished: true,
          };
          break;
        case "exit":
          state = {
            ...state,
            shouldExit: true,
          };
          break;
      }

      emit();
    },
  };
};
