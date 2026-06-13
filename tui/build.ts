/**
 * @fileoverview Build script for bundling TUI into a single JS file.
 *
 * Uses Bun.build() with the @opentui/solid bun-plugin to perform
 * Solid JSX transforms at build time instead of runtime.
 *
 * Output: tui/dist/index.js + tui/dist/prompts/helper.js + libopentui.so
 */
import { copyFileSync, existsSync, mkdirSync, readFileSync } from "fs";
import { join } from "path";
import solidTransformPlugin from "@opentui/solid/bun-plugin";
import {
  getNativeLibraryName,
  getNativePackageName,
  OPENTUI_NATIVE_EXTERNALS,
} from "./build_config.ts";

const TUI_DIR = import.meta.dir;
const DIST_DIR = join(TUI_DIR, "dist");
const PROMPTS_DIST_DIR = join(DIST_DIR, "prompts");

// Ensure dist directory exists
mkdirSync(DIST_DIR, { recursive: true });

const uiResult = await Bun.build({
  entrypoints: [join(TUI_DIR, "src/index.tsx")],
  outdir: DIST_DIR,
  target: "bun",
  plugins: [solidTransformPlugin],
  // Native platform packages are resolved at runtime through the dist shim.
  external: OPENTUI_NATIVE_EXTERNALS,
});

if (!uiResult.success) {
  console.error("Build failed:");
  for (const log of uiResult.logs) {
    console.error(log);
  }
  process.exit(1);
}

console.log(`✓ TUI bundle created: ${uiResult.outputs.map((o) => o.path).join(", ")}`);

const bundledIndexPath = join(DIST_DIR, "index.js");
const bundledIndexContent = readFileSync(bundledIndexPath, "utf8");
const coreEnvRegistrationMatches = bundledIndexContent.match(
  /name: "OTUI_DUMP_CAPTURES"/g,
);
if ((coreEnvRegistrationMatches?.length ?? 0) !== 1) {
  throw new Error(
    `Expected exactly one OpenTUI core env registry path in bundle, found ${
      coreEnvRegistrationMatches?.length ?? 0
    }.`,
  );
}

mkdirSync(PROMPTS_DIST_DIR, { recursive: true });

const promptResult = await Bun.build({
  entrypoints: [join(TUI_DIR, "src/prompts/helper.ts")],
  outdir: PROMPTS_DIST_DIR,
  target: "bun",
});

if (!promptResult.success) {
  console.error("Prompt helper build failed:");
  for (const log of promptResult.logs) {
    console.error(log);
  }
  process.exit(1);
}

console.log(`✓ Prompt helper bundle created: ${promptResult.outputs.map((o) => o.path).join(", ")}`);

// Step 2: Copy libopentui.so to dist
const platform = process.platform;
const arch = process.arch;
const nativePkg = getNativePackageName(platform, arch);
const soName = getNativeLibraryName(platform);
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
