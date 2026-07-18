import type { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: "https://tokenout.scrubmac.app",
      lastModified: new Date("2026-07-18"),
      changeFrequency: "weekly",
      priority: 1,
    },
    {
      url: "https://tokenout.scrubmac.app/releases",
      lastModified: new Date("2026-07-18"),
      changeFrequency: "monthly",
      priority: 0.7,
    },
    {
      url: "https://tokenout.scrubmac.app/privacy",
      lastModified: new Date("2026-07-18"),
      changeFrequency: "yearly",
      priority: 0.4,
    },
  ];
}
