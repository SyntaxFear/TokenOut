import { track } from "@vercel/analytics/server";
import { NextRequest, NextResponse } from "next/server";
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

  const analytics = track("Download Requested", {
    placement,
    version: siteConfig.latestVersion,
  }).catch((error) => {
    console.error("Unable to record download analytics", error);
  });

  let downloadIsAvailable = false;
  try {
    const response = await fetch(siteConfig.directDownloadURL, {
      method: "HEAD",
      redirect: "manual",
      cache: "no-store",
      signal: AbortSignal.timeout(4_000),
    });
    downloadIsAvailable = response.ok || (response.status >= 300 && response.status < 400);
  } catch (error) {
    console.error("Unable to verify the latest download", error);
  }

  await analytics;

  const destination = downloadIsAvailable
    ? siteConfig.directDownloadURL
    : `${siteConfig.repositoryURL}/releases`;
  return NextResponse.redirect(destination, 307);
}
