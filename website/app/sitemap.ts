import type { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: "https://burnbar.scrubmac.app",
      lastModified: new Date("2026-07-18"),
      changeFrequency: "weekly",
      priority: 1,
    },
    {
      url: "https://burnbar.scrubmac.app/privacy",
      lastModified: new Date("2026-07-18"),
      changeFrequency: "yearly",
      priority: 0.4,
    },
  ];
}
