import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Privacy",
  description: "How BurnBar handles local usage data, provider sessions, updates, and diagnostics.",
  alternates: { canonical: "/privacy" },
};

export default function PrivacyPage() {
  return (
    <main className="legal-page">
      <header className="site-nav">
        <Link className="brand" href="/">
          <Image src="/assets/burnbar-symbol.png" alt="" width={34} height={22} />
          <span>BurnBar</span>
        </Link>
        <Link className="text-link" href="/">Back to BurnBar</Link>
      </header>
      <article className="legal-copy shell">
        <p className="eyebrow">Privacy</p>
        <h1>Your data stays local.</h1>
        <p className="legal-intro">
          BurnBar is designed to show usage without creating another account or collecting a new copy of your activity.
        </p>

        <h2>Data BurnBar reads</h2>
        <p>
          BurnBar reads local usage records, configuration, and existing session material created by supported tools on your Mac.
          This is used to calculate token totals, recent activity, usage windows, and reset times.
        </p>

        <h2>Network requests</h2>
        <p>
          When a provider supports a live quota endpoint, BurnBar may send the provider&apos;s existing session token only to that
          provider&apos;s official service. BurnBar also requests its signed update feed from burnbar.scrubmac.app.
        </p>

        <h2>What BurnBar does not collect</h2>
        <p>
          BurnBar has no analytics SDK, advertising SDK, user account, telemetry backend, or cloud sync. It does not sell or share
          your usage history.
        </p>

        <h2>Storage</h2>
        <p>
          Preferences and derived local history stay on your Mac. Existing provider credentials remain in the storage selected by
          that provider, including the macOS Keychain where applicable.
        </p>

        <h2>Open source</h2>
        <p>
          The application source is public so its data paths can be inspected. Questions can be opened in the project&apos;s GitHub repository.
        </p>

        <p className="legal-updated">Effective July 18, 2026.</p>
      </article>
    </main>
  );
}
