import type { Metadata, Viewport } from "next";
import { Geist_Mono, Manrope } from "next/font/google";
import { Analytics } from "@vercel/analytics/next";
import { siteConfig } from "@/lib/site";
import "./globals.css";

const manrope = Manrope({ variable: "--font-sans", subsets: ["latin"] });
const geistMono = Geist_Mono({ variable: "--font-mono", subsets: ["latin"] });

export const metadata: Metadata = {
  metadataBase: new URL(siteConfig.siteURL),
  title: {
    default: "TokenOut | AI usage, limits, and cost in your Mac menu bar",
    template: "%s | TokenOut",
  },
  description: siteConfig.description,
  applicationName: "TokenOut",
  category: "technology",
  referrer: "origin-when-cross-origin",
  keywords: [
    "AI usage tracker",
    "Claude Code usage",
    "Codex usage",
    "Antigravity usage",
    "macOS menu bar app",
    "token tracker",
    "AI rate limit monitor",
    "AI cost tracker",
  ],
  authors: [{ name: "Levan Parastashvili", url: siteConfig.repositoryURL }],
  creator: "Levan Parastashvili",
  publisher: "TokenOut",
  alternates: { canonical: "/" },
  openGraph: {
    title: "TokenOut | Every AI limit. One glance.",
    description: "Claude Code, Codex, and Antigravity limits, tokens, cost, and history in one native Mac menu bar app.",
    url: "/",
    siteName: "TokenOut",
    type: "website",
    images: [{ url: "/opengraph-image.png", width: 1200, height: 630, alt: "TokenOut for macOS" }],
  },
  twitter: {
    card: "summary_large_image",
    title: "TokenOut | Every AI limit. One glance.",
    description: "Track AI coding-tool limits, tokens, cost, and history without leaving the menu bar.",
    images: ["/opengraph-image.png"],
  },
  icons: {
    icon: [{ url: "/icon.png", type: "image/png", sizes: "512x512" }],
    shortcut: "/icon.png",
    apple: [{ url: "/apple-icon.png", type: "image/png", sizes: "180x180" }],
  },
  manifest: "/manifest.webmanifest",
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-image-preview": "large",
      "max-snippet": -1,
      "max-video-preview": -1,
    },
  },
};

export const viewport: Viewport = {
  colorScheme: "dark light",
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#f5f6f7" },
    { media: "(prefers-color-scheme: dark)", color: "#0d0d0f" },
  ],
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className={`${manrope.variable} ${geistMono.variable}`}>
      <body>
        {children}
        <Analytics />
      </body>
    </html>
  );
}
