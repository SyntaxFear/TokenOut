import Image from "next/image";
import Link from "next/link";
import {
  ArrowDown,
  ArrowUpRight,
  BellSimple,
  ChartLineUp,
  CheckCircle,
  ClockCounterClockwise,
  Command,
  Gauge,
  GithubLogo,
  LockKey,
  ShieldCheck,
  Sparkle,
} from "@phosphor-icons/react/dist/ssr";
import { HeroVisual, Reveal } from "@/components/reveal";

const downloadURL = "https://github.com/SyntaxFear/BurnBar/releases/latest/download/BurnBar.dmg";

const softwareSchema = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "BurnBar",
  applicationCategory: "UtilitiesApplication",
  operatingSystem: "macOS 14 or later",
  description: "A native menu bar app for tracking Claude Code, Codex, and Antigravity usage.",
  downloadUrl: downloadURL,
  softwareVersion: "1.0.0",
  author: { "@type": "Person", name: "Levan Parastashvili" },
};

export default function Home() {
  return (
    <main>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(softwareSchema) }}
      />

      <header className="site-nav">
        <Link className="brand" href="/" aria-label="BurnBar home">
          <Image src="/assets/burnbar-symbol.png" alt="" width={34} height={22} priority />
          <span>BurnBar</span>
        </Link>
        <nav aria-label="Primary navigation">
          <a href="#features">Features</a>
          <Link href="/privacy">Privacy</Link>
          <a href="https://github.com/SyntaxFear/BurnBar" target="_blank" rel="noreferrer">
            GitHub
          </a>
        </nav>
        <a className="button button-small" href={downloadURL}>
          <ArrowDown aria-hidden="true" />
          Download for Mac
        </a>
      </header>

      <section className="hero shell">
        <Reveal className="hero-copy">
          <p className="eyebrow">Native macOS usage monitor</p>
          <h1>Know the burn before limits hit.</h1>
          <p className="hero-subtitle">
            See Claude Code, Codex, and Antigravity usage without leaving the menu bar.
          </p>
          <div className="hero-actions">
            <a className="button" href={downloadURL}>
              <ArrowDown aria-hidden="true" />
              Download for Mac
            </a>
            <a className="text-link" href="https://github.com/SyntaxFear/BurnBar" target="_blank" rel="noreferrer">
              <GithubLogo aria-hidden="true" />
              View source
            </a>
          </div>
          <p className="requirements">macOS 14+, Apple silicon and Intel, no account</p>
        </Reveal>

        <HeroVisual>
          <div className="hero-image-frame">
            <Image
              src="/assets/hero-product.png"
              alt="BurnBar app icon beside its macOS menu bar usage popover"
              width={1536}
              height={1024}
              priority
              sizes="(max-width: 900px) 100vw, 55vw"
            />
          </div>
          <p className="image-caption">Sample usage data shown.</p>
        </HeroVisual>
      </section>

      <section className="provider-rail shell" aria-label="Supported tools">
        <span>Works with</span>
        <strong>Claude Code</strong>
        <strong>Codex</strong>
        <strong>Antigravity</strong>
      </section>

      <section className="statement shell" id="features">
        <Reveal>
          <h2>One calm place for every limit window.</h2>
          <p>
            BurnBar turns scattered provider data into a compact view of usage, reset times,
            tokens, cost estimates, and recent pace.
          </p>
        </Reveal>
        <Reveal className="statement-metrics" delay={0.08}>
          <div>
            <span>3</span>
            <p>coding tools</p>
          </div>
          <div>
            <span>1</span>
            <p>menu bar glance</p>
          </div>
          <div>
            <span>0</span>
            <p>BurnBar accounts</p>
          </div>
        </Reveal>
      </section>

      <section className="feature-grid shell">
        <Reveal className="feature feature-wide feature-usage">
          <Gauge aria-hidden="true" />
          <h3>See what is running hot</h3>
          <p>Used or remaining percentages stay consistent across hourly, weekly, and monthly windows.</p>
          <div className="meter-demo" aria-label="Example usage at 72 percent">
            <span style={{ width: "72%" }} />
          </div>
          <small>72% used</small>
        </Reveal>

        <Reveal className="feature feature-visual" delay={0.05}>
          <Image src="/assets/burnbar-app-icon.png" alt="BurnBar app icon" width={1024} height={1024} />
        </Reveal>

        <Reveal className="feature" delay={0.08}>
          <ChartLineUp aria-hidden="true" />
          <h3>Track pace, not only totals</h3>
          <p>Daily charts and local history show when usage accelerates and when a limit may be reached.</p>
        </Reveal>

        <Reveal className="feature feature-accent" delay={0.12}>
          <BellSimple aria-hidden="true" />
          <h3>Get useful warnings</h3>
          <p>Choose warning and critical thresholds, plus an optional notification when capacity refills.</p>
        </Reveal>
      </section>

      <section className="privacy-story shell">
        <Reveal className="privacy-mark">
          <Image src="/assets/burnbar-symbol.png" alt="BurnBar flame meter symbol" width={665} height={401} />
        </Reveal>
        <Reveal className="privacy-copy" delay={0.08}>
          <LockKey aria-hidden="true" />
          <h2>Your usage stays on your Mac.</h2>
          <p>
            BurnBar reads local tool data and contacts only each provider&apos;s official service when a live quota refresh is needed.
          </p>
          <ul>
            <li><CheckCircle aria-hidden="true" /> No analytics or advertising SDKs</li>
            <li><CheckCircle aria-hidden="true" /> No BurnBar account or cloud sync</li>
            <li><CheckCircle aria-hidden="true" /> Open source and inspectable</li>
          </ul>
          <Link className="text-link" href="/privacy">
            Read the privacy details
            <ArrowUpRight aria-hidden="true" />
          </Link>
        </Reveal>
      </section>

      <section className="detail-band shell">
        <Reveal>
          <Command aria-hidden="true" />
          <h3>Native by design</h3>
          <p>SwiftUI, fast launch, small footprint, and a real menu bar workflow.</p>
        </Reveal>
        <Reveal delay={0.05}>
          <ClockCounterClockwise aria-hidden="true" />
          <h3>Automatic updates</h3>
          <p>Signed Sparkle updates keep BurnBar current without a manual reinstall.</p>
        </Reveal>
        <Reveal delay={0.1}>
          <ShieldCheck aria-hidden="true" />
          <h3>Signed for macOS</h3>
          <p>Developer ID signing and Apple notarization protect each public release.</p>
        </Reveal>
      </section>

      <section className="faq shell">
        <Reveal>
          <h2>Questions, answered.</h2>
        </Reveal>
        <div className="faq-list">
          <details>
            <summary>Does BurnBar need my provider password?</summary>
            <p>No. It uses each installed tool&apos;s existing local session and never asks for your password.</p>
          </details>
          <details>
            <summary>Why can Antigravity show less data?</summary>
            <p>Antigravity does not expose every quota locally. BurnBar shows verified local activity and labels unavailable limits clearly.</p>
          </details>
          <details>
            <summary>Can I choose what appears?</summary>
            <p>Yes. Providers, detail sections, charts, breakdowns, refresh cadence, menu bar style, and alerts are configurable.</p>
          </details>
          <details>
            <summary>How do updates work?</summary>
            <p>BurnBar checks a signed Sparkle feed and verifies both the update archive and the macOS code signature.</p>
          </details>
        </div>
      </section>

      <section className="final-cta shell">
        <Reveal>
          <Sparkle aria-hidden="true" />
          <h2>Keep the burn visible.</h2>
          <p>Install BurnBar and make your next limit predictable.</p>
          <a className="button" href={downloadURL}>
            <ArrowDown aria-hidden="true" />
            Download for Mac
          </a>
        </Reveal>
      </section>

      <footer className="site-footer shell">
        <Link className="brand" href="/">
          <Image src="/assets/burnbar-symbol.png" alt="" width={30} height={20} />
          <span>BurnBar</span>
        </Link>
        <p>Native AI usage monitoring for macOS.</p>
        <div>
          <Link href="/privacy">Privacy</Link>
          <a href="https://github.com/SyntaxFear/BurnBar">GitHub</a>
        </div>
      </footer>
    </main>
  );
}
