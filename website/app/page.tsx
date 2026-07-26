import Image from "next/image";
import Link from "next/link";
import {
  ArrowDown,
  ArrowUpRight,
  BellRinging,
  ChartBar,
  CheckCircle,
  ClockCounterClockwise,
  Command,
  GithubLogo,
  GlobeSimple,
  LockKey,
  PaintBrush,
  ShareNetwork,
  SlidersHorizontal,
} from "@phosphor-icons/react/dist/ssr";
import { HeroVisual, Reveal } from "@/components/reveal";
import { latestRelease, siteConfig } from "@/lib/site";

const downloadURL = siteConfig.downloadURL;
const repositoryURL = siteConfig.repositoryURL;

const structuredData = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "WebSite",
      "@id": `${siteConfig.siteURL}/#website`,
      url: siteConfig.siteURL,
      name: siteConfig.name,
      description: siteConfig.description,
      inLanguage: "en",
    },
    {
      "@type": "SoftwareApplication",
      "@id": `${siteConfig.siteURL}/#software`,
      name: siteConfig.name,
      alternateName: "TokenOut for macOS",
      applicationCategory: "UtilitiesApplication",
      applicationSubCategory: "Developer tools",
      operatingSystem: siteConfig.minimumOS,
      description: siteConfig.description,
      url: siteConfig.siteURL,
      downloadUrl: downloadURL,
      installUrl: downloadURL,
      codeRepository: repositoryURL,
      releaseNotes: `${siteConfig.siteURL}/releases`,
      softwareVersion: latestRelease.version,
      datePublished: latestRelease.date,
      dateModified: latestRelease.date,
      fileFormat: "application/x-apple-diskimage",
      isAccessibleForFree: true,
      offers: { "@type": "Offer", price: "0", priceCurrency: "USD", availability: "https://schema.org/InStock" },
      screenshot: [
        `${siteConfig.siteURL}/assets/app-popover-real.png`,
        `${siteConfig.siteURL}/assets/settings-display-ui.png`,
      ],
      featureList: [
        "Claude Code usage limits",
        "OpenAI Codex usage limits",
        "Token and cost history",
        "Native macOS menu bar interface",
        "Signed automatic updates",
      ],
      author: { "@type": "Person", name: "Levan Parastashvili", url: repositoryURL },
    },
  ],
};

const providers = [
  {
    name: "Claude Code",
    logo: "/assets/provider-claude.png",
    summary: "Live 5-hour and weekly limits, transcript totals, model mix, and cost estimates.",
  },
  {
    name: "Codex",
    logo: "/assets/provider-codex.png",
    summary: "Primary and secondary rate limits, rollout history, plan details, and workspace breakdowns.",
  },
];

export default function Home() {
  return (
    <>
      <a className="skip-link" href="#main-content">
        Skip to content
      </a>

      <header className="site-nav site-shell">
        <Link className="brand" href="/" aria-label="TokenOut home">
          <Image src="/assets/tokenout-symbol.png" alt="" width={32} height={32} priority />
          <span>TokenOut</span>
        </Link>

        <nav aria-label="Primary navigation">
          <a href="#product">Product</a>
          <a href="#details">Details</a>
          <Link href="/releases">Releases</Link>
          <Link href="/privacy">Privacy</Link>
          <a href={repositoryURL} target="_blank" rel="noreferrer">
            GitHub
          </a>
        </nav>

        <a className="button button-compact" href={`${downloadURL}?placement=header`}>
          <ArrowDown aria-hidden="true" />
          <span className="download-long">Download for Mac</span>
          <span className="download-short">Download</span>
        </a>
      </header>

      <main id="main-content">
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
        />

        <section className="hero site-shell">
          <Reveal className="hero-copy">
            <p className="eyebrow">Claude Code + Codex usage monitor</p>
            <h1>Know your limits before they slow you down.</h1>
            <p className="hero-subtitle">
              See live usage, reset times, tokens, cost, and history for both tools—without leaving your Mac menu bar.
            </p>
            <div className="hero-actions">
              <a className="button" href={`${downloadURL}?placement=hero`}>
                <ArrowDown aria-hidden="true" />
                Download TokenOut v{latestRelease.version}
              </a>
              <a className="text-link" href={repositoryURL} target="_blank" rel="noreferrer">
                <GithubLogo aria-hidden="true" />
                View on GitHub
              </a>
            </div>
          </Reveal>

          <HeroVisual>
            <div className="hero-frame">
              <Image
                src="/assets/hero-product.png"
                alt="TokenOut app icon beside the real macOS usage popover"
                width={3072}
                height={2048}
                priority
                sizes="(max-width: 960px) 100vw, 58vw"
              />
            </div>
          </HeroVisual>
        </section>

        <section className="compatibility-bar site-shell" aria-label="Compatibility">
          <span>macOS 14 or later</span>
          <span>Apple silicon and Intel</span>
          <span>No TokenOut account</span>
          <span>Open source</span>
        </section>

        <section className="provider-section site-shell" aria-labelledby="providers-heading">
          <Reveal className="provider-intro">
            <h2 id="providers-heading">Two tools. One place to stay ahead.</h2>
            <p>TokenOut gives Claude Code and Codex the detail each tool actually exposes, in one focused view.</p>
          </Reveal>

          <div className="provider-list">
            {providers.map((provider, index) => (
              <Reveal className="provider-row" delay={index * 0.05} key={provider.name}>
                <span className="provider-logo">
                  <Image src={provider.logo} alt={`${provider.name} logo`} width={256} height={256} />
                </span>
                <div>
                  <h3>{provider.name}</h3>
                  <p>{provider.summary}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </section>

        <section className="product-section site-shell" id="product">
          <Reveal className="section-heading">
            <h2>See the pressure before the cutoff.</h2>
            <p>
              The compact overview keeps both limit horizons and today&apos;s usage visible. Expand one provider when you want the complete history.
            </p>
          </Reveal>

          <div className="product-stage">
            <Reveal className="popover-capture">
              <Image
                src="/assets/app-popover-real.png"
                alt="TokenOut compact overview showing 5-hour and weekly limits plus today's usage for Claude Code and Codex"
                width={340}
                height={547}
                sizes="(max-width: 760px) 88vw, 340px"
              />
              <p>Actual app interface with sample usage data.</p>
            </Reveal>

            <div className="product-notes">
              <Reveal className="product-note">
                <SlidersHorizontal aria-hidden="true" />
                <div>
                  <h3>Compact first, detailed on demand</h3>
                  <p>See both limits immediately, then expand only the provider you want to inspect.</p>
                </div>
              </Reveal>
              <Reveal className="product-note" delay={0.05}>
                <ChartBar aria-hidden="true" />
                <div>
                  <h3>7 to 90 days of history</h3>
                  <p>Plot tokens or API-equivalent cost and spot the days your pace changed.</p>
                </div>
              </Reveal>
              <Reveal className="product-note" delay={0.1}>
                <BellRinging aria-hidden="true" />
                <div>
                  <h3>Warnings that follow the cycle</h3>
                  <p>Set warning and critical thresholds, plus an alert when capacity refills.</p>
                </div>
              </Reveal>
              <Reveal className="product-note" delay={0.15}>
                <ClockCounterClockwise aria-hidden="true" />
                <div>
                  <h3>Refresh without babysitting</h3>
                  <p>TokenOut speeds up near higher usage and backs off after provider failures.</p>
                </div>
              </Reveal>
            </div>
          </div>
        </section>

        <section className="details-section site-shell" id="details">
          <Reveal className="section-heading details-heading">
            <h2>More context, less checking.</h2>
            <p>Go from a quick limit check to a useful record of how your AI coding time is being spent.</p>
          </Reveal>

          <div className="details-grid">
            <Reveal className="detail-card settings-card">
              <div className="detail-card-copy">
                <PaintBrush aria-hidden="true" />
                <h3>Show exactly what matters.</h3>
                <p>Combine the icon, gauge, percentage, provider split, today&apos;s tokens, and cost—then choose how limits read.</p>
              </div>
              <Image
                src="/assets/settings-display-ui.png"
                alt="The real TokenOut Display settings window with combinable menu bar components, limit direction, charts, and breakdowns"
                width={680}
                height={492}
                sizes="(max-width: 760px) 100vw, 62vw"
              />
            </Reveal>

            <Reveal className="detail-card share-card" delay={0.05}>
              <div className="detail-card-copy">
                <ShareNetwork aria-hidden="true" />
                <h3>Share a clean usage snapshot.</h3>
                <p>Export today, this week, or the last 30 days as a ready-to-post image.</p>
              </div>
              <Image
                src="/assets/share-card.png"
                alt="TokenOut share card with weekly tokens, cost, providers, models, and daily activity"
                width={960}
                height={1068}
                sizes="(max-width: 760px) 90vw, 34vw"
              />
            </Reveal>

            <Reveal className="detail-card language-card" delay={0.08}>
              <div className="detail-card-copy">
                <GlobeSimple aria-hidden="true" />
                <h3>Built to fit your Mac.</h3>
                <p>System, light, or dark appearance. Four text sizes. Thirteen font choices. Ten app languages.</p>
              </div>
              <div className="language-sample" aria-label="Supported TokenOut languages">
                <span>English</span>
                <span>Español</span>
                <span>中文</span>
                <span>हिन्दी</span>
                <span>العربية</span>
                <span>Português</span>
                <span>Русский</span>
                <span>日本語</span>
                <span>Deutsch</span>
                <span>Français</span>
              </div>
            </Reveal>

            <Reveal className="detail-card native-card" delay={0.12}>
              <div className="native-mark">
                <Image src="/assets/tokenout-app-icon.png" alt="TokenOut app icon" width={1024} height={1024} />
              </div>
              <div className="detail-card-copy">
                <Command aria-hidden="true" />
                <h3>Native all the way through.</h3>
                <p>SwiftUI, no Dock icon, launch at login, a universal binary, and signed Sparkle updates.</p>
              </div>
            </Reveal>
          </div>
        </section>

        <section className="privacy-section site-shell">
          <Reveal className="privacy-visual">
            <Image src="/assets/tokenout-symbol.png" alt="TokenOut mark" width={1024} height={1024} />
            <span>Local by default</span>
          </Reveal>

          <Reveal className="privacy-copy" delay={0.06}>
            <LockKey aria-hidden="true" />
            <h2>Your usage stays on your Mac.</h2>
            <p>
              TokenOut reads local tool data and contacts only each provider&apos;s official service when a live quota refresh is available.
            </p>
            <div className="privacy-points">
              <span><CheckCircle aria-hidden="true" /> No provider-usage telemetry</span>
              <span><CheckCircle aria-hidden="true" /> No cloud sync</span>
              <span><CheckCircle aria-hidden="true" /> No separate account</span>
            </div>
            <Link className="text-link" href="/privacy">
              Read the privacy details
              <ArrowUpRight aria-hidden="true" />
            </Link>
          </Reveal>
        </section>

        <section className="answers-section site-shell" aria-labelledby="answers-heading">
          <Reveal className="answers-title">
            <h2 id="answers-heading">The practical questions.</h2>
          </Reveal>

          <div className="answer-grid">
            <Reveal>
              <h3>Does it need my provider password?</h3>
              <p>No. TokenOut uses the existing local session created by each installed tool.</p>
            </Reveal>
            <Reveal delay={0.04}>
              <h3>Why does each provider show different data?</h3>
              <p>TokenOut shows only what each provider exposes reliably, then labels unavailable values clearly.</p>
            </Reveal>
            <Reveal delay={0.08}>
              <h3>Can I choose what appears?</h3>
              <p>Yes. Providers, metrics, sections, charts, breakdowns, themes, fonts, languages, refresh, and alerts are configurable.</p>
            </Reveal>
            <Reveal delay={0.12}>
              <h3>How are updates protected?</h3>
              <p>Public releases are notarized by Apple and verified again with TokenOut&apos;s Sparkle signing key.</p>
            </Reveal>
          </div>
        </section>

        <section className="download-section site-shell">
          <Reveal className="download-panel">
            <div>
              <h2>Keep Claude and Codex within reach.</h2>
              <p>Install TokenOut and check both tools from one fast, native menu bar view.</p>
            </div>
            <a className="button" href={`${downloadURL}?placement=footer-cta`}>
              <ArrowDown aria-hidden="true" />
              Download for Mac
            </a>
          </Reveal>
        </section>
      </main>

      <footer className="site-footer site-shell">
        <Link className="brand" href="/" aria-label="TokenOut home">
          <Image src="/assets/tokenout-symbol.png" alt="" width={28} height={28} />
          <span>TokenOut</span>
        </Link>
        <p>Claude Code and Codex usage, live in your Mac menu bar.</p>
        <div>
          <Link href="/privacy">Privacy</Link>
          <Link href="/releases">Releases</Link>
          <a href={repositoryURL}>GitHub</a>
        </div>
        <small>© 2026 Levan Parastashvili</small>
      </footer>
    </>
  );
}
