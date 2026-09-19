import { cp, mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

import { build } from "esbuild";

const FUNCTION_RELATIVE_PATH = join(
  "functions",
  "api",
  "v1",
  "cpu",
  "very-hard.func",
);

export interface BuildVercelOutputOptions {
  root: string;
  staticDir: string;
  outputDir: string;
  bundlePath: string;
}

export async function buildVercelOutput(
  options: BuildVercelOutputOptions,
): Promise<void> {
  const staticIndex = join(options.staticDir, "index.html");
  await assertFile(
    staticIndex,
    `Flutter Web output is missing: ${staticIndex}`,
  );
  await assertFile(
    options.bundlePath,
    `Function bundle is missing: ${options.bundlePath}`,
  );

  await rm(options.outputDir, { recursive: true, force: true });
  const staticOutput = join(options.outputDir, "static");
  const functionOutput = join(options.outputDir, FUNCTION_RELATIVE_PATH);
  await mkdir(functionOutput, { recursive: true });
  await cp(options.staticDir, staticOutput, { recursive: true });
  await cp(options.bundlePath, join(functionOutput, "index.js"));
  await writeFile(
    join(functionOutput, "package.json"),
    `${JSON.stringify({ type: "commonjs" })}\n`,
  );

  const sourceVercelConfig = await readVercelConfig(options.root);
  const routes = buildRoutes(sourceVercelConfig);
  await writeFile(
    join(options.outputDir, "config.json"),
    `${JSON.stringify({ version: 3, routes }, null, 2)}\n`,
  );
  await writeFile(
    join(functionOutput, ".vc-config.json"),
    `${JSON.stringify(
      {
        runtime: "nodejs22.x",
        handler: "index.js",
        maxDuration: 3,
        launcherType: "Nodejs",
        shouldAddHelpers: true,
        shouldAddSourcemapSupport: true,
      },
      null,
    )}\n`,
  );
}

export async function bundleVeryHardFunction(
  root: string,
  bundlePath: string,
): Promise<void> {
  await mkdir(resolve(bundlePath, ".."), { recursive: true });
  await build({
    entryPoints: [join(root, "api", "v1", "cpu", "very-hard.ts")],
    bundle: true,
    platform: "node",
    target: "node22",
    format: "cjs",
    outfile: bundlePath,
    sourcemap: false,
    footer: { js: "module.exports = vercelHandler;" },
    logLevel: "silent",
  });
}

export async function checkVercelOutput(outputDir: string): Promise<void> {
  const config = JSON.parse(
    await readFile(join(outputDir, "config.json"), "utf8"),
  ) as { version?: unknown };
  if (config.version !== 3)
    throw new Error("Build Output API config must use version 3.");
  await assertFile(
    join(outputDir, FUNCTION_RELATIVE_PATH, "index.js"),
    "Build Output API Function bundle is missing.",
  );
  await assertFile(
    join(outputDir, FUNCTION_RELATIVE_PATH, ".vc-config.json"),
    "Build Output API Function config is missing.",
  );
  await assertFile(
    join(outputDir, "static", "index.html"),
    "Build Output API static index is missing.",
  );
}

interface SourceVercelConfig {
  headers?: Array<{ source?: unknown; headers?: unknown }>;
}

async function readVercelConfig(root: string): Promise<SourceVercelConfig> {
  try {
    return JSON.parse(
      await readFile(join(root, "vercel.json"), "utf8"),
    ) as SourceVercelConfig;
  } catch (error) {
    if (isNodeError(error) && error.code === "ENOENT") return {};
    throw error;
  }
}

function buildRoutes(
  config: SourceVercelConfig,
): Array<Record<string, unknown>> {
  const routes: Array<Record<string, unknown>> = [];
  for (const entry of config.headers ?? []) {
    if (typeof entry.source !== "string") continue;
    const headers: Record<string, string> = {};
    if (isRecord(entry.headers)) {
      for (const [key, value] of Object.entries(entry.headers)) {
        if (typeof value === "string") headers[key] = value;
      }
    } else if (Array.isArray(entry.headers)) {
      for (const header of entry.headers) {
        if (!isRecord(header)) continue;
        const key = header.key;
        const value = header.value;
        if (typeof key === "string" && typeof value === "string") {
          headers[key] = value;
        }
      }
    }
    if (Object.keys(headers).length > 0) {
      routes.push({ src: entry.source, headers, continue: true });
    }
  }
  return routes;
}

async function assertFile(path: string, message: string): Promise<void> {
  try {
    await readFile(path);
  } catch {
    throw new Error(message);
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isNodeError(error: unknown): error is NodeJS.ErrnoException {
  return error instanceof Error && "code" in error;
}

async function main(): Promise<void> {
  const root = resolve(process.cwd());
  const outputDir = join(root, ".vercel", "output");
  if (process.argv.includes("--check")) {
    await checkVercelOutput(outputDir);
    return;
  }

  const temporaryDir = await mkdtemp(
    join(tmpdir(), "conquest-vercel-function-"),
  );
  const bundlePath = join(temporaryDir, "index.js");
  try {
    await bundleVeryHardFunction(root, bundlePath);
    await buildVercelOutput({
      root,
      staticDir: join(root, "build", "web"),
      outputDir,
      bundlePath,
    });
  } finally {
    await rm(temporaryDir, { recursive: true, force: true });
  }
  await checkVercelOutput(outputDir);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  await main();
}
