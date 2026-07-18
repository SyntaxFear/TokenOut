import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import {
  ArrowDown,
  ArrowLeft,
  ArrowSquareOut,
  CheckCircle,
  ClockCounterClockwise,
  GithubLogo,
} from "@phosphor-icons/react/dist/ssr";
import { releases, siteConfig } from "@/lib/site";

export const metadata: Metadata = {
  title: "Releases and downloads",
  description: "Download the latest notarized TokenOut release and review the complete macOS app release history.",
  alternates: { canonical: "/releases" },
  openGraph: {
    title: "TokenOut releases and downloads",
    description: "Download TokenOut for macOS and review release notes, compatibility, and update details.",
    url: "/releases",
    type: "website",
    images: [{ url: "/opengraph-image.png", width: 1200, height: 630, alt: "TokenOut for macOS" }],
  },
  twitter: {
    card: "summary_large_image",
    title: "TokenOut releases and downloads",
    description: "The latest TokenOut version, release notes, and automatic-update information.",
    images: ["/opengraph-image.png"],
  },
};

const releaseSchema = {
  "@context": "https://schema.org",
  "@type": "CollectionPage",
  name: "TokenOut releases and downloads",
  url: `${siteConfig.siteURL}/releases`,
  description: "TokenOut release history and official macOS downloads.",
  mainEntity: releases.map((release) => ({
    "@type": "SoftwareApplication",
    name: `TokenOut ${release.version}`,
    softwareVersion: release.version,
    datePublished: release.date,
    operatingSystem: siteConfig.minimumOS,
    downloadUrl: release.downloadURL,
    releaseNotes: release.sourceURL,
  })),
};

export default function ReleasesPage() {
  return (
    <>
      <a className="skip-link" href="#release-history">Skip to release history</a>
      <header className="site-nav site-shell legal-nav">
        <Link className="brand" href="/" aria-label="TokenOut home">
          <Image src="/assets/tokenout-symbol.png" alt="" width={32} height={32} priority />
          <span>TokenOut</span>
        </Link>
        <div className="legal-nav-actions">
          <Link className="legal-history-link" href="/privacy">Privacy</Link>
          <Link className="button button-compact button-secondary" href="/">
            <ArrowLeft aria-hidden="true" />
            Back to TokenOut
          </Link>
        </div>
      </header>

      <main className="release-page" id="main-content">
        <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(releaseSchema) }} />

        <section className="release-hero site-shell">
          <div>
            <p className="eyebrow">Official downloads</p>
            <h1>Release history.</h1>
            <p>
              Download the latest notarized build, see what changed, or let TokenOut check its signed Sparkle feed automatically.
            </p>
          </div>
          <div className="release-download-card">
            <Image src="/assets/tokenout-app-icon.png" alt="TokenOut app icon" width={1024} height={1024} priority />
            <div>
              <span>Latest release</span>
              <strong>TokenOut {siteConfig.latestVersion}</strong>
              <small>{siteConfig.minimumOS} · Apple silicon and Intel</small>
            </div>
            <a className="button" href={siteConfig.downloadURL}>
              <ArrowDown aria-hidden="true" />
              Download DMG
            </a>
          </div>
        </section>

        <section className="release-assurance site-shell" aria-label="Release assurances">
          <span><CheckCircle aria-hidden="true" /> Developer ID signed</span>
          <span><CheckCircle aria-hidden="true" /> Apple notarized</span>
          <span><CheckCircle aria-hidden="true" /> Sparkle feed signed</span>
          <span><CheckCircle aria-hidden="true" /> Universal macOS build</span>
        </section>

        <section className="release-history site-shell" id="release-history">
          <div className="release-history-heading">
            <div>
              <p className="eyebrow">Changelog</p>
              <h2>Every public version.</h2>
            </div>
            <a className="text-link" href={`${siteConfig.repositoryURL}/releases`}>
              <GithubLogo aria-hidden="true" />
              GitHub releases
              <ArrowSquareOut aria-hidden="true" />
            </a>
          </div>

          <div className="release-list">
            {releases.map((release, index) => (
              <article className="release-entry" key={release.version}>
                <div className="release-version">
                  <span>{index === 0 ? "Current" : "Previous"}</span>
                  <strong>v{release.version}</strong>
                  <time dateTime={release.date}>{new Date(`${release.date}T12:00:00Z`).toLocaleDateString("en", { year: "numeric", month: "long", day: "numeric", timeZone: "UTC" })}</time>
                </div>
                <div className="release-notes">
                  <h3>{release.title}</h3>
                  <p>{release.summary}</p>
                  <ul>
                    {release.highlights.map((highlight) => <li key={highlight}>{highlight}</li>)}
                  </ul>
                  <div className="release-entry-actions">
                    <a className="text-link" href={release.downloadURL}><ArrowDown aria-hidden="true" /> Download</a>
                    <a className="text-link" href={release.sourceURL}>Full notes <ArrowSquareOut aria-hidden="true" /></a>
                  </div>
                </div>
              </article>
            ))}
          </div>
        </section>

        <section className="update-explainer site-shell">
          <ClockCounterClockwise aria-hidden="true" />
          <div>
            <h2>Updates arrive inside TokenOut.</h2>
            <p>
              Open Settings → Updates to check manually or enable automatic checks and downloads. Every update is verified before installation.
            </p>
          </div>
          <a className="text-link" href={siteConfig.appcastURL}>View update feed <ArrowSquareOut aria-hidden="true" /></a>
        </section>
      </main>

      <footer className="site-footer site-shell">
        <Link className="brand" href="/" aria-label="TokenOut home">
          <Image src="/assets/tokenout-symbol.png" alt="" width={28} height={28} />
          <span>TokenOut</span>
        </Link>
        <p>Private AI usage monitoring for macOS.</p>
        <div>
          <Link href="/privacy">Privacy</Link>
          <a href={siteConfig.repositoryURL}>GitHub</a>
        </div>
        <small>© 2026 Levan Parastashvili</small>
      </footer>
    </>
  );
}
