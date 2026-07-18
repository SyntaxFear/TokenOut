import { track } from "@vercel/analytics/server";
import { NextRequest, NextResponse } from "next/server";

const maxBodyBytes = 2_048;
const maxPropertyLength = 64;

function cleanProperty(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const cleaned = value.trim().slice(0, maxPropertyLength);
  return cleaned || null;
}

export async function POST(request: NextRequest) {
  const contentLength = Number(request.headers.get("content-length") ?? 0);
  if (contentLength > maxBodyBytes) {
    return NextResponse.json({ error: "Payload too large" }, { status: 413 });
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  const appVersion = cleanProperty(body.appVersion);
  const build = cleanProperty(body.build);
  const macOSVersion = cleanProperty(body.macOSVersion);
  const architecture = cleanProperty(body.architecture);

  if (!appVersion || !build || !macOSVersion || !architecture) {
    return NextResponse.json({ error: "Missing analytics properties" }, { status: 400 });
  }

  try {
    await track("App Installed", {
      appVersion,
      build,
      macOSVersion,
      architecture,
    });
  } catch (error) {
    console.error("Unable to record install analytics", error);
    return NextResponse.json({ error: "Analytics temporarily unavailable" }, { status: 503 });
  }

  return new NextResponse(null, {
    status: 204,
    headers: { "Cache-Control": "no-store" },
  });
}
