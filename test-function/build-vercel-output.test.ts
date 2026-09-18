import { mkdir, mkdtemp, readFile, writeFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

import {
  buildVercelOutput,
  bundleVeryHardFunction,
} from "../scripts/build_vercel_output.js";

describe("Build Output API assembly", () => {
  it("places Flutter static files and the Node Function in one version 3 artifact", async () => {
    const root = await mkdtemp(join(tmpdir(), "conquest-vercel-output-"));
    const staticDir = join(root, "build", "web");
    const outputDir = join(root, ".vercel", "output");
    const bundlePath = join(root, "function-bundle.js");
    await mkdir(join(staticDir, "assets"), { recursive: true });
    await writeFile(join(staticDir, "index.html"), "<html></html>");
    await writeFile(join(staticDir, "assets", "main.js"), 'console.log("ok")');
    await writeFile(bundlePath, "exports.default = () => {};");
    await writeFile(
      join(root, "package.json"),
      JSON.stringify({ type: "module" }),
    );
    await writeFile(
      join(root, "vercel.json"),
      JSON.stringify({
        headers: [
          {
            source: "/(.*)",
            headers: [
              { key: "Cross-Origin-Opener-Policy", value: "same-origin" },
            ],
          },
        ],
      }),
    );

    await buildVercelOutput({ root, staticDir, outputDir, bundlePath });

    expect(
      await readFile(join(outputDir, "static", "index.html"), "utf8"),
    ).toBe("<html></html>");
    expect(
      await readFile(join(outputDir, "static", "assets", "main.js"), "utf8"),
    ).toContain("console.log");
    expect(
      await readFile(
        join(
          outputDir,
          "functions",
          "api",
          "v1",
          "cpu",
          "very-hard.func",
          "index.js",
        ),
        "utf8",
      ),
    ).toContain("exports.default");
    expect(
      JSON.parse(await readFile(join(outputDir, "config.json"), "utf8")),
    ).toMatchObject({
      version: 3,
      routes: [
        {
          src: "/(.*)",
          continue: true,
          headers: { "Cross-Origin-Opener-Policy": "same-origin" },
        },
      ],
    });
    expect(
      JSON.parse(
        await readFile(
          join(
            outputDir,
            "functions",
            "api",
            "v1",
            "cpu",
            "very-hard.func",
            ".vc-config.json",
          ),
          "utf8",
        ),
      ),
    ).toMatchObject({
      runtime: "nodejs22.x",
      handler: "index.js",
      launcherType: "Nodejs",
    });
    expect(
      JSON.parse(
        await readFile(
          join(
            outputDir,
            "functions",
            "api",
            "v1",
            "cpu",
            "very-hard.func",
            "package.json",
          ),
          "utf8",
        ),
      ),
    ).toEqual({ type: "commonjs" });
  });

  it("exports the bundled Function as the Node handler entrypoint", async () => {
    const root = process.cwd();
    const temporaryDir = await mkdtemp(
      join(tmpdir(), "conquest-vercel-function-bundle-"),
    );
    const bundlePath = join(temporaryDir, "index.cjs");

    await bundleVeryHardFunction(root, bundlePath);

    const handler = createRequire(import.meta.url)(bundlePath);
    expect(typeof handler).toBe("function");
  });
});
