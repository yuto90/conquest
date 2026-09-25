import { createHash } from "node:crypto";
import { promises as fs } from "node:fs";
import path from "node:path";
import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";

const SCREENSHOTS_DIR_REL = path.join("public", "screenshots");
const UPLOAD_DIR_REL = path.join(SCREENSHOTS_DIR_REL, "uploaded");
const PUBLIC_PREFIX = "/screenshots/uploaded";

const MIME_EXT: Record<string, string> = {
  "image/png": "png",
  "image/jpeg": "jpg",
  "image/jpg": "jpg",
};

function parseDataUrl(dataUrl: string): { mime: string; bytes: Buffer } | null {
  const m = /^data:([^;]+);base64,(.+)$/.exec(dataUrl);
  if (!m) return null;
  const mime = m[1].toLowerCase();
  const bytes = Buffer.from(m[2], "base64");
  return { mime, bytes };
}

function localizedTarget(targetPath: string, ext: string): { absFile: string; publicPath: string } | null {
  const normalized = path.posix.normalize(targetPath);
  if (!normalized.startsWith("/screenshots/") || path.posix.extname(normalized) !== `.${ext}`) {
    return null;
  }
  const screenshotsRoot = path.resolve(process.cwd(), SCREENSHOTS_DIR_REL);
  const absFile = path.resolve(process.cwd(), "public", normalized.slice(1));
  if (!absFile.startsWith(`${screenshotsRoot}${path.sep}`)) return null;
  return { absFile, publicPath: normalized };
}

export async function POST(req: Request) {
  let body: { dataUrl?: string; targetPath?: string };
  try {
    body = (await req.json()) as { dataUrl?: string; targetPath?: string };
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid JSON" }, { status: 400 });
  }
  if (!body?.dataUrl || typeof body.dataUrl !== "string") {
    return NextResponse.json({ ok: false, error: "Missing dataUrl" }, { status: 400 });
  }
  const parsed = parseDataUrl(body.dataUrl);
  if (!parsed) {
    return NextResponse.json({ ok: false, error: "Unsupported data URL" }, { status: 400 });
  }
  const ext = MIME_EXT[parsed.mime];
  if (!ext) {
    return NextResponse.json(
      { ok: false, error: `Unsupported mime: ${parsed.mime}` },
      { status: 400 },
    );
  }
  if (parsed.bytes.byteLength > 8 * 1024 * 1024) {
    return NextResponse.json({ ok: false, error: "Image too large (>8MB)" }, { status: 413 });
  }

  const target = body.targetPath ? localizedTarget(body.targetPath, ext) : null;
  if (body.targetPath && !target) {
    return NextResponse.json(
      { ok: false, error: "Invalid localized screenshot target" },
      { status: 400 },
    );
  }

  const hash = createHash("sha1").update(parsed.bytes).digest("hex").slice(0, 16);
  const filename = `${hash}.${ext}`;
  const absFile = target?.absFile ?? path.join(process.cwd(), UPLOAD_DIR_REL, filename);
  const publicPath = target?.publicPath ?? `${PUBLIC_PREFIX}/${filename}`;

  try {
    await fs.mkdir(path.dirname(absFile), { recursive: true });
    if (target) {
      await fs.writeFile(absFile, parsed.bytes);
    } else {
      try {
        await fs.access(absFile);
      } catch {
        await fs.writeFile(absFile, parsed.bytes);
      }
    }
    return NextResponse.json({ ok: true, path: publicPath });
  } catch (e) {
    return NextResponse.json(
      { ok: false, error: e instanceof Error ? e.message : String(e) },
      { status: 500 },
    );
  }
}
