import { NextResponse } from "next/server";

interface GitHubAsset {
  name: string;
  download_count: number;
}

interface GitHubRelease {
  tag_name: string;
  published_at: string | null;
  draft: boolean;
  prerelease: boolean;
  assets: GitHubAsset[];
}

export async function GET() {
  const headers: HeadersInit = {
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "TokenOut-Website",
  };
  if (process.env.GITHUB_TOKEN) {
    headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
  }

  const response = await fetch("https://api.github.com/repos/SyntaxFear/TokenOut/releases?per_page=100", {
    headers,
    next: { revalidate: 300 },
  });

  if (!response.ok) {
    return NextResponse.json(
      { error: "Unable to retrieve GitHub download counts" },
      { status: 502 },
    );
  }

  const releases = (await response.json()) as GitHubRelease[];
  const publicReleases = releases
    .filter((release) => !release.draft && !release.prerelease)
    .map((release) => {
      const assets = release.assets
        .filter((asset) => asset.name.toLowerCase().endsWith(".dmg"))
        .map((asset) => ({ name: asset.name, downloads: asset.download_count }));

      return {
        version: release.tag_name,
        publishedAt: release.published_at,
        downloads: assets.reduce((sum, asset) => sum + asset.downloads, 0),
        assets,
      };
    });

  return NextResponse.json(
    {
      totalDownloads: publicReleases.reduce((sum, release) => sum + release.downloads, 0),
      releases: publicReleases,
      generatedAt: new Date().toISOString(),
      note: "GitHub counters are cumulative per asset and can include repeat or automated requests; they are not unique people.",
    },
    { headers: { "Cache-Control": "public, s-maxage=300, stale-while-revalidate=3600" } },
  );
}
