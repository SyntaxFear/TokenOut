import { NextRequest, NextResponse } from "next/server";
import { captureAnonymousEvent } from "@/lib/analytics";
import { siteConfig } from "@/lib/site";

const allowedPlacements = new Set([
  "header",
  "hero",
  "footer-cta",
  "releases-hero",
  "release-history",
]);

export async function GET(request: NextRequest) {
  const requestedPlacement = request.nextUrl.searchParams.get("placement") ?? "direct";
  const placement = allowedPlacements.has(requestedPlacement) ? requestedPlacement : "direct";

  const properties = {
    placement,
    version: siteConfig.latestVersion,
  };
  await captureAnonymousEvent("download_requested", properties);

  return NextResponse.redirect(siteConfig.directDownloadURL, 307);
}
