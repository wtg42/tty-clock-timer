import { TextAttributes } from "@opentui/core";
import { useKeyboard, useTimeline } from "@opentui/solid";
import type { Accessor } from "solid-js";
import { onMount } from "solid-js";

import type { CommandName } from "./protocol.ts";
import type { TimerViewState } from "./store.ts";
import { commandFromKey, formatRemaining } from "./ui_logic.ts";

type AppProps = {
  state: Accessor<TimerViewState>;
  lastCommandError: Accessor<string | null>;
  onCommand: (command: CommandName) => void;
  animateFinishedView?: boolean;
};

type FinishedViewProps = {
  animate?: boolean;
};

export const FinishedView = (props: FinishedViewProps) => {
  let containerRef: any;
  let titleRef: any;

  const timeline = useTimeline({ autoplay: true });

  onMount(() => {
    if (props.animate === false) return;

    timeline.add(
      containerRef,
      { opacity: 1, duration: 800, ease: "outBounce" },
      0,
    );
    timeline.add(titleRef, {
      translateY: -2,
      duration: 100,
      ease: "outElastic",
    }, 800);
    timeline.add(
      titleRef,
      { translateY: 0, duration: 100, ease: "outBounce" },
      900,
    );
    timeline.add(
      containerRef,
      {
        opacity: 0.85,
        duration: 1000,
        ease: "inOutQuad",
        loop: true,
        alternate: true,
      },
      1000,
    );
  });

  return (
    <box
      ref={containerRef}
      opacity={props.animate === false ? 1 : 0}
      flexDirection="column"
      alignItems="center"
      justifyContent="center"
    >
      <ascii_font ref={titleRef} font="tiny" text="TIME'S UP!" />
      <text attributes={TextAttributes.BOLD}>Press s to restart or q to exit</text>
    </box>
  );
};

export const App = (props: AppProps) => {
  useKeyboard((key) => {
    if (key.eventType !== "press") return;

    const command = commandFromKey(key.name);
    if (!command) return;

    props.onCommand(command);
  });

  return (
    <box
      alignItems="center"
      justifyContent="center"
      flexGrow={1}
      flexDirection="column"
    >
      {!props.state().isFinished
        ? (
          <box
            justifyContent="center"
            alignItems="center"
            flexDirection="column"
          >
            <ascii_font font="tiny" text="TTY Clock Timer" />
            <ascii_font
              font="slick"
              text={formatRemaining(props.state().remainingSeconds)}
              margin={1}
            />
            <box flexDirection="column" alignItems="center">
              <text attributes={TextAttributes.DIM}>
                ETA {props.state().etaHhmm ?? "--:--"}
              </text>
              <text attributes={TextAttributes.DIM}>
                Status: {props.state().status}
              </text>
              <text attributes={TextAttributes.DIM}>
                Keys: p pause / r resume / s reset / q quit
              </text>
            </box>
          </box>
        )
        : <FinishedView animate={props.animateFinishedView} />}

      {props.lastCommandError()
        ? (
          <text attributes={TextAttributes.BOLD}>
            Command error: {props.lastCommandError()}
          </text>
        )
        : null}
    </box>
  );
};
