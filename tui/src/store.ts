import type { CoreEvent } from "./protocol.ts";

export type TimerViewState = {
  remainingSeconds: number | null;
  status: string;
  isFinished: boolean;
  shouldExit: boolean;
};

const initialState: TimerViewState = {
  remainingSeconds: null,
  status: "connecting",
  isFinished: false,
  shouldExit: false,
};

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
        case "update_timer":
          state = {
            ...state,
            remainingSeconds: event.remaining_seconds,
            status: event.status,
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
