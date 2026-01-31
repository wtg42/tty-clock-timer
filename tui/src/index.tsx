import { TextAttributes } from "@opentui/core";
import { render } from "@opentui/solid";

// OpenTUI 入口渲染
// 步驟：
// 1. 建立版面容器
// 2. 放置 ASCII 標題與提示文字
render(() => (
  <box alignItems="center" justifyContent="center" flexGrow={1}>
    <box justifyContent="center" alignItems="flex-end">
      <ascii_font font="tiny" text="OpenTUI" />
      <text attributes={TextAttributes.DIM}>What will you build?</text>
    </box>
  </box>
));
