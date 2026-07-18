import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { ArrowLeft, GithubLogo } from "@phosphor-icons/react/dist/ssr";
import { siteConfig } from "@/lib/site";

export const metadata: Metadata = {
  title: "Privacy policy",
  description: "How TokenOut handles local usage data, provider sessions, updates, and diagnostics.",
  alternates: { canonical: "/privacy" },
  openGraph: {
    title: "TokenOut privacy policy",
    description: "TokenOut keeps usage history on your Mac and has no analytics, telemetry, account, or cloud sync.",
    url: "/privacy",
    type: "website",
    images: [{ url: "/opengraph-image.png", width: 1200, height: 630, alt: "TokenOut for macOS" }],
  },
  twitter: {
    card: "summary_large_image",
    title: "TokenOut privacy policy",
    description: "Local-first AI usage monitoring for macOS.",
    images: ["/opengraph-image.png"],
  },
};

export default function PrivacyPage() {
  return (
    <>
      <a className="skip-link" href="#privacy-content">Skip to privacy details</a>
      <header className="site-nav site-shell legal-nav">
        <Link className="brand" href="/" aria-label="TokenOut home">
          <Image src="/assets/tokenout-symbol.png" alt="" width={32} height={32} priority />
          <span>TokenOut</span>
        </Link>
        <div className="legal-nav-actions">
          <Link className="legal-history-link" href="/releases">Release history</Link>
          <Link className="button button-compact button-secondary" href="/">
            <ArrowLeft aria-hidden="true" />
            Back to TokenOut
          </Link>
        </div>
      </header>

      <main className="legal-page" id="main-content">
        <article className="legal-copy site-shell" id="privacy-content">
          <p className="eyebrow">Privacy policy</p>
          <h1>Your data stays local.</h1>
          <p className="legal-intro">
            TokenOut shows usage without creating another account or sending a copy of your activity to a TokenOut service.
          </p>

          <h2>Data TokenOut reads</h2>
          <p>
            TokenOut reads local usage records, configuration, and existing session material created by supported tools on your Mac.
            This is used to calculate token totals, recent activity, usage windows, and reset times.
          </p>

          <h2>Network requests</h2>
          <p>
            When a provider supports a live quota endpoint, TokenOut may send the provider&apos;s existing session token only to that
            provider&apos;s official service. TokenOut also requests its signed update feed from tokenout.scrubmac.app.
          </p>

          <h2>What TokenOut does not collect</h2>
          <p>
            TokenOut has no analytics SDK, advertising SDK, user account, telemetry backend, or cloud sync. It does not sell or share
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

      <footer className="site-footer site-shell">
        <Link className="brand" href="/" aria-label="TokenOut home">
          <Image src="/assets/tokenout-symbol.png" alt="" width={28} height={28} />
          <span>TokenOut</span>
        </Link>
        <p>Private AI usage monitoring for macOS.</p>
        <div>
          <Link href="/releases">Releases</Link>
          <a href={siteConfig.repositoryURL}><GithubLogo aria-hidden="true" /> GitHub</a>
        </div>
        <small>© 2026 Levan Parastashvili</small>
      </footer>
    </>
  );
}
