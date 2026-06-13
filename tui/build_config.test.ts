import { describe, expect, test } from "bun:test";

import {
  getNativeLibraryName,
  getNativePackageName,
  OPENTUI_NATIVE_EXTERNALS,
} from "./build_config.ts";

describe("build config", () => {
  test("OpenTUI native package variants stay external", () => {
    expect(OPENTUI_NATIVE_EXTERNALS).toEqual([
      "@opentui/core-linux-x64",
      "@opentui/core-linux-arm64",
      "@opentui/core-linux-x64-musl",
      "@opentui/core-linux-arm64-musl",
      "@opentui/core-darwin-x64",
      "@opentui/core-darwin-arm64",
      "@opentui/core-win32-x64",
      "@opentui/core-win32-arm64",
    ]);
    expect(new Set(OPENTUI_NATIVE_EXTERNALS).size).toBe(
      OPENTUI_NATIVE_EXTERNALS.length,
    );
  });

  test("native package and library names match runtime platform", () => {
    expect(getNativePackageName("darwin", "arm64")).toBe(
      "@opentui/core-darwin-arm64",
    );
    expect(getNativePackageName("linux", "x64")).toBe(
      "@opentui/core-linux-x64",
    );
    expect(getNativeLibraryName("darwin")).toBe("libopentui.dylib");
    expect(getNativeLibraryName("linux")).toBe("libopentui.so");
  });
});
