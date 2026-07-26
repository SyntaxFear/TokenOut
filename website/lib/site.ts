export const siteConfig = {
  name: "TokenOut",
  tagline: "Claude and Codex. One clear view.",
  description:
    "Stay ahead of Claude Code and Codex limits with live usage, reset times, tokens, cost, and history in one native Mac menu bar app.",
  siteURL: "https://tokenout.scrubmac.app",
  repositoryURL: "https://github.com/SyntaxFear/TokenOut",
  downloadURL: "https://tokenout.scrubmac.app/download",
  directDownloadURL: "https://github.com/SyntaxFear/TokenOut/releases/latest/download/TokenOut.dmg",
  appcastURL: "https://tokenout.scrubmac.app/appcast.xml",
  minimumOS: "macOS 14 or later",
  latestVersion: "1.2.0",
  releaseDate: "2026-07-26",
} as const;

export const releases = [
  {
    version: "1.2.0",
    date: "2026-07-26",
    title: "A calmer overview",
    summary:
      "Both limit horizons and today's usage now fit into a compact, readable provider card, with the complete analytics view one click away.",
    highlights: [
      "See the active 5-hour limit and the tightest weekly limit together for Claude Code and Codex.",
      "Read today's tokens and API-equivalent value in one concise grouped row.",
      "Expand either provider independently for every limit, projection, breakdown, metric tile, and daily chart.",
      "Neutral adaptive bars and calmer charts reserve orange and red for conditions that actually need attention.",
      "Larger sentence-case labels and reduced-motion-aware spring transitions improve readability and comfort.",
    ],
    downloadURL: "https://tokenout.scrubmac.app/download?placement=release-history",
    sourceURL: "https://github.com/SyntaxFear/TokenOut/releases/tag/v1.2.0",
  },
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
    downloadURL: "https://tokenout.scrubmac.app/download?placement=release-history",
    sourceURL: "https://github.com/SyntaxFear/TokenOut/releases/tag/v1.1.0",
  },
  {
    version: "1.0.0",
    date: "2026-07-18",
    title: "First public release",
    summary:
      "The complete TokenOut launch for Claude Code and Codex usage monitoring.",
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
