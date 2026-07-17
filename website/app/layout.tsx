import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geist = Geist({ variable: "--font-sans", subsets: ["latin"] });
const geistMono = Geist_Mono({ variable: "--font-mono", subsets: ["latin"] });

export const metadata: Metadata = {
  metadataBase: new URL("https://burnbar.scrubmac.app"),
  title: {
    default: "BurnBar | AI usage in your Mac menu bar",
    template: "%s | BurnBar",
  },
  description:
    "Track Claude Code, Codex, and Antigravity usage from a private native macOS menu bar app.",
  applicationName: "BurnBar",
  keywords: [
    "AI usage tracker",
    "Claude Code usage",
    "Codex usage",
    "Antigravity usage",
    "macOS menu bar app",
    "token tracker",
  ],
  authors: [{ name: "Levan Parastashvili" }],
  creator: "Levan Parastashvili",
  alternates: { canonical: "/" },
  openGraph: {
    title: "BurnBar | Know your AI burn",
    description: "Claude Code, Codex, and Antigravity usage in one native Mac menu bar app.",
    url: "/",
    siteName: "BurnBar",
    type: "website",
    images: [{ url: "/opengraph-image.png", width: 1200, height: 630, alt: "BurnBar for macOS" }],
  },
  twitter: {
    card: "summary_large_image",
    title: "BurnBar | Know your AI burn",
    description: "Track AI coding-tool usage without leaving the menu bar.",
    images: ["/opengraph-image.png"],
  },
  icons: {
    icon: "/assets/burnbar-symbol.png",
    apple: "/assets/burnbar-app-icon.png",
  },
};

export const viewport: Viewport = {
  colorScheme: "dark light",
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#f4f2ee" },
    { media: "(prefers-color-scheme: dark)", color: "#11100f" },
  ],
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className={`${geist.variable} ${geistMono.variable}`}>
      <body>{children}</body>
    </html>
  );
}
