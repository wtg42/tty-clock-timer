/**
 * @fileoverview Build script for bundling TUI into a single JS file.
 *
 * Uses Bun.build() with the @opentui/solid bun-plugin to perform
 * Solid JSX transforms at build time instead of runtime.
 *
 * Output: tui/dist/tui.js + libopentui.so
 */
import { existsSync, mkdirSync, copyFileSync } from "fs";
import { join, dirname } from "path";
import solidTransformPlugin from "@opentui/solid/bun-plugin";

const ROOT = dirname(import.meta.dir);
const TUI_DIR = import.meta.dir;
const DIST_DIR = join(TUI_DIR, "dist");

// Ensure dist directory exists
mkdirSync(DIST_DIR, { recursive: true });

// Step 1: Bundle JS/TS with Solid plugin
const result = await Bun.build({
  entrypoints: [join(TUI_DIR, "src/index.tsx")],
  outdir: DIST_DIR,
  target: "bun",
  plugins: [solidTransformPlugin],
  external: [
    // Native platform packages — resolved at runtime via dynamic import
    "@opentui/core-linux-x64",
    "@opentui/core-linux-arm64",
    "@opentui/core-darwin-x64",
    "@opentui/core-darwin-arm64",
    "@opentui/core-win32-x64",
    "@opentui/core-win32-arm64",
  ],
});

if (!result.success) {
  console.error("Build failed:");
  for (const log of result.logs) {
    console.error(log);
  }
  process.exit(1);
}

console.log(`✓ Bundle created: ${result.outputs.map(o => o.path).join(", ")}`);

// Step 2: Copy libopentui.so to dist
const platform = process.platform;
const arch = process.arch;
const nativePkg = `@opentui/core-${platform}-${arch}`;
const soName = platform === "darwin" ? "libopentui.dylib" : "libopentui.so";
const soSrc = join(TUI_DIR, "node_modules", nativePkg, soName);

if (existsSync(soSrc)) {
  const soDst = join(DIST_DIR, soName);
  copyFileSync(soSrc, soDst);
  console.log(`✓ Copied ${soName} to dist/`);
} else {
  console.warn(`⚠ Native library not found: ${soSrc}`);
}

// Step 3: Create a minimal index.ts shim for the native package
// so the bundled code can resolve `@opentui/core-<platform>-<arch>/index.ts`
// at runtime from the dist directory.
const shimDir = join(DIST_DIR, "node_modules", nativePkg);
mkdirSync(shimDir, { recursive: true });
const shimContent = `import { resolve, dirname } from "path";\nconst soPath = resolve(dirname(Bun.main), "${soName}");\nexport default soPath;\n`;
await Bun.write(join(shimDir, "index.ts"), shimContent);
console.log(`✓ Created native package shim at dist/node_modules/${nativePkg}/index.ts`);

console.log("\nBuild complete!");
