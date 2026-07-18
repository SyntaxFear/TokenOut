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
    default: "TokenOut | Claude Code and Codex usage in your Mac menu bar",
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
    title: "TokenOut | Stay ahead of Claude Code and Codex limits",
    description: "Live limits, reset times, tokens, cost, and history for Claude Code and Codex in one native Mac menu bar app.",
    url: "/",
    siteName: "TokenOut",
    type: "website",
    images: [{ url: "/opengraph-image.png", width: 1200, height: 630, alt: "TokenOut for macOS" }],
  },
  twitter: {
    card: "summary_large_image",
    title: "TokenOut | Claude Code and Codex at a glance",
    description: "Know your limits, reset times, tokens, and cost without leaving the Mac menu bar.",
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
