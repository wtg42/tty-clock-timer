import { describe, expect, test } from "bun:test";
import { testRender } from "@opentui/solid";
import { createSignal } from "solid-js";

import { App } from "./app.tsx";
import type { TimerViewState } from "./store.ts";

const createViewState = (overrides: Partial<TimerViewState> = {}): TimerViewState => ({
  remainingSeconds: 65,
  status: "running",
  etaHhmm: "14:30",
  isFinished: false,
  shouldExit: false,
  sound: null,
  ...overrides,
});

describe("app integration", () => {
  test("renders countdown screen contract", async () => {
    const [state] = createSignal(createViewState());
    const [lastCommandError] = createSignal<string | null>(null);

    const view = await testRender(() => (
      <App
        state={state}
        lastCommandError={lastCommandError}
        onCommand={() => {}}
      />
    ), { width: 80, height: 24 });

    await view.renderOnce();
    const frame = view.captureCharFrame();

    expect(frame).toContain("▀█▀ ▀█▀ █▄█");
    expect(frame).toContain("╭━━━╮ ╱╭╮╱");
    expect(frame).toContain("ETA 14:30");
    expect(frame).toContain("Status: running");
    expect(frame).toContain("Keys: p pause / r resume / s reset / q quit");

    view.renderer.destroy();
  });

  test("renders finished screen contract", async () => {
    const [state] = createSignal(createViewState({
      remainingSeconds: 0,
      status: "finished",
      etaHhmm: null,
      isFinished: true,
    }));
    const [lastCommandError] = createSignal<string | null>(null);

    const view = await testRender(() => (
      <App
        state={state}
        lastCommandError={lastCommandError}
        onCommand={() => {}}
        animateFinishedView={false}
      />
    ), { width: 80, height: 24 });

    await view.renderOnce();
    const frame = view.captureCharFrame();

    expect(frame).toContain("▀█▀ █ █▀▄▀█");
    expect(frame).toContain("Press s to restart or q to exit");

    view.renderer.destroy();
  });

  test("renders finished screen with animation enabled", async () => {
    const [state] = createSignal(createViewState({
      remainingSeconds: 0,
      status: "finished",
      etaHhmm: null,
      isFinished: true,
    }));
    const [lastCommandError] = createSignal<string | null>(null);

    const view = await testRender(() => (
      <App
        state={state}
        lastCommandError={lastCommandError}
        onCommand={() => {}}
      />
    ), { width: 80, height: 24 });

    await view.renderOnce();
    const frame = view.captureCharFrame();

    expect(frame).toContain("▀█▀ █ █▀▄▀█");
    expect(frame).toContain("Press s to restart or q to exit");

    view.renderer.destroy();
  });

  test("renders error message without hiding timer contract", async () => {
    const [state] = createSignal(createViewState());
    const [lastCommandError] = createSignal<string | null>("socket_not_connected");

    const view = await testRender(() => (
      <App
        state={state}
        lastCommandError={lastCommandError}
        onCommand={() => {}}
      />
    ), { width: 80, height: 24 });

    await view.renderOnce();
    const frame = view.captureCharFrame();

    expect(frame).toContain("▀█▀ ▀█▀ █▄█");
    expect(frame).toContain("╭━━━╮ ╱╭╮╱");
    expect(frame).toContain("Command error: socket_not_connected");

    view.renderer.destroy();
  });

  test("keyboard input triggers mapped command flow", async () => {
    const [state] = createSignal(createViewState());
    const [lastCommandError] = createSignal<string | null>(null);
    const commands: string[] = [];

    const view = await testRender(() => (
      <App
        state={state}
        lastCommandError={lastCommandError}
        onCommand={(command) => {
          commands.push(command);
        }}
      />
    ), { width: 80, height: 24 });

    await view.renderOnce();
    view.mockInput.pressKey("p");
    view.mockInput.pressKey("x");
    await view.renderOnce();

    expect(commands).toEqual(["pause"]);

    view.renderer.destroy();
  });
});
