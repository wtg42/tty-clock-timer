/**
 * @fileoverview Unit tests for timer store state projection.
 */
import { describe, expect, test } from "bun:test";

import { createTimerStore } from "./store.ts";

describe("store/createTimerStore", () => {
  test("createTimerStore - normal initial state", () => {
    const store = createTimerStore();

    expect(store.getState()).toEqual({
      remainingSeconds: null,
      status: "connecting",
      etaHhmm: null,
      isFinished: false,
      shouldExit: false,
      sound: null,
    });
  });

  test("createTimerStore - init event stores sound config", () => {
    const store = createTimerStore();

    store.applyEvent({
      type: "init",
      sound: {
        player: "/usr/bin/paplay",
        file: "/tmp/ding.wav",
      },
    });

    expect(store.getState().sound).toEqual({
      player: "/usr/bin/paplay",
      file: "/tmp/ding.wav",
    });
  });

  test("createTimerStore - normal update_timer event projection", () => {
    const store = createTimerStore();

    store.applyEvent({
      type: "update_timer",
      remaining_seconds: 42,
      total_duration: 300,
      status: "running",
      eta_epoch_seconds: 52200,
    });

    const state = store.getState();
    expect(state.remainingSeconds).toBe(42);
    expect(state.status).toBe("running");
    expect(state.isFinished).toBe(false);
    expect(state.shouldExit).toBe(false);
    expect(state.sound).toBe(null);
    // etaHhmm is formatted from epoch, just verify it's a valid time string
    expect(state.etaHhmm).toMatch(/^\d{2}:\d{2}$/);
  });

  test("createTimerStore - edge timer_finished event forces finished state", () => {
    const store = createTimerStore();

    store.applyEvent({
      type: "timer_finished",
      total_duration: 300,
    });

    expect(store.getState()).toEqual({
      remainingSeconds: 0,
      status: "finished",
      etaHhmm: null,
      isFinished: true,
      shouldExit: false,
      sound: null,
    });
  });

  test("createTimerStore - edge exit event sets shouldExit", () => {
    const store = createTimerStore();

    store.applyEvent({ type: "exit" });

    expect(store.getState().shouldExit).toBe(true);
  });

  test("createTimerStore - edge unknown event keeps state unchanged", () => {
    const store = createTimerStore();
    const before = store.getState();

    store.applyEvent({ type: "unknown" } as never);

    expect(store.getState()).toEqual(before);
  });

  test("createTimerStore - normal subscribe receives projected state", () => {
    const store = createTimerStore();
    const events: Array<{ status: string; remainingSeconds: number | null }> = [];

    const unsubscribe = store.subscribe((nextState) => {
      events.push({
        status: nextState.status,
        remainingSeconds: nextState.remainingSeconds,
      });
    });

    store.applyEvent({
      type: "update_timer",
      remaining_seconds: 10,
      total_duration: 60,
      status: "running",
      eta_epoch_seconds: 52200,
    });

    unsubscribe();

    expect(events).toEqual([
      {
        status: "running",
        remainingSeconds: 10,
      },
    ]);
  });
});
