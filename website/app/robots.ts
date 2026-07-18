import type { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: { userAgent: "*", allow: "/" },
    sitemap: "https://tokenout.scrubmac.app/sitemap.xml",
    host: "https://tokenout.scrubmac.app",
  };
}
