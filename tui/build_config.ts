export const OPENTUI_NATIVE_EXTERNALS = [
  "@opentui/core-linux-x64",
  "@opentui/core-linux-arm64",
  "@opentui/core-linux-x64-musl",
  "@opentui/core-linux-arm64-musl",
  "@opentui/core-darwin-x64",
  "@opentui/core-darwin-arm64",
  "@opentui/core-win32-x64",
  "@opentui/core-win32-arm64",
] as const;

export const getNativePackageName = (
  platform: NodeJS.Platform,
  arch: NodeJS.Architecture,
) => `@opentui/core-${platform}-${arch}`;

export const getNativeLibraryName = (platform: NodeJS.Platform) =>
  platform === "darwin" ? "libopentui.dylib" : "libopentui.so";
