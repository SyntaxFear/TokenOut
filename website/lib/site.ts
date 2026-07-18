export const siteConfig = {
  name: "TokenOut",
  tagline: "Every AI limit. One glance.",
  description:
    "Track Claude Code, Codex, and Antigravity limits, tokens, cost, history, and reset times from a private native macOS menu bar app.",
  siteURL: "https://tokenout.scrubmac.app",
  repositoryURL: "https://github.com/SyntaxFear/TokenOut",
  downloadURL: "https://tokenout.scrubmac.app/download",
  directDownloadURL: "https://github.com/SyntaxFear/TokenOut/releases/latest/download/TokenOut.dmg",
  appcastURL: "https://tokenout.scrubmac.app/appcast.xml",
  minimumOS: "macOS 14 or later",
  latestVersion: "1.1.0",
  releaseDate: "2026-07-18",
} as const;

export const releases = [
  {
    version: "1.1.0",
    date: "2026-07-18",
    title: "The TokenOut release",
    summary:
      "BurnBar is now TokenOut — new identity, shareable usage cards, pace metrics, a customizable menu bar, and a full pricing audit.",
    highlights: [
      "Share your usage as polished PNG cards: totals, API-equivalent value, per-provider split, models used, peak day, and daily average.",
      "Pace metrics on every limit window: human refill countdowns with exact reset times, plus over-pace / in-reserve indicators.",
      "Combinable menu bar readout: icon, usage gauge, percentage, per-provider split, today's tokens, and today's cost.",
      "Themes, four text sizes, 12 bundled fonts, 10 languages with live switching, and a redesigned native Settings window.",
      "Pricing verified against current Anthropic and OpenAI rates, resumed-session double-count fix, and graceful rate-limit handling.",
    ],
    downloadURL: "https://github.com/SyntaxFear/TokenOut/releases/latest/download/TokenOut.dmg",
    sourceURL: "https://github.com/SyntaxFear/TokenOut/releases/tag/v1.1.0",
  },
  {
    version: "1.0.0",
    date: "2026-07-18",
    title: "First public release",
    summary:
      "The complete TokenOut launch for Claude Code, Codex, and Antigravity usage monitoring.",
    highlights: [
      "Live provider limit windows, reset times, token totals, and API-equivalent cost estimates.",
      "Configurable menu bar metrics, charts, breakdowns, notifications, appearance, fonts, and ten languages.",
      "Local-first usage history with no TokenOut account, advertising SDK, or cloud sync.",
      "Universal Apple silicon and Intel build with signed Sparkle automatic updates.",
    ],
    downloadURL: "https://tokenout.scrubmac.app/download?placement=release-history",
    sourceURL: "https://github.com/SyntaxFear/TokenOut/releases/tag/v1.0.0",
  },
] as const;

export const latestRelease = releases[0];
