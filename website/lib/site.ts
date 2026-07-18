export const siteConfig = {
  name: "TokenOut",
  tagline: "Every AI limit. One glance.",
  description:
    "Track Claude Code, Codex, and Antigravity limits, tokens, cost, history, and reset times from a private native macOS menu bar app.",
  siteURL: "https://tokenout.scrubmac.app",
  repositoryURL: "https://github.com/SyntaxFear/TokenOut",
  downloadURL: "https://github.com/SyntaxFear/TokenOut/releases/latest/download/TokenOut.dmg",
  appcastURL: "https://tokenout.scrubmac.app/appcast.xml",
  minimumOS: "macOS 14 or later",
  latestVersion: "1.0.0",
  releaseDate: "2026-07-18",
} as const;

export const releases = [
  {
    version: "1.0.0",
    date: "2026-07-18",
    title: "First public release",
    summary:
      "The complete TokenOut launch for Claude Code, Codex, and Antigravity usage monitoring.",
    highlights: [
      "Live provider limit windows, reset times, token totals, and API-equivalent cost estimates.",
      "Configurable menu bar metrics, charts, breakdowns, notifications, appearance, fonts, and ten languages.",
      "Local-first history with no TokenOut account, analytics, telemetry, or cloud sync.",
      "Universal Apple silicon and Intel build with signed Sparkle automatic updates.",
    ],
    downloadURL: "https://github.com/SyntaxFear/TokenOut/releases/latest/download/TokenOut.dmg",
    sourceURL: "https://github.com/SyntaxFear/TokenOut/releases/tag/v1.0.0",
  },
] as const;

export const latestRelease = releases[0];
