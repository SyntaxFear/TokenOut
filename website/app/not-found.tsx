import Image from "next/image";
import Link from "next/link";
import { ArrowLeft } from "@phosphor-icons/react/dist/ssr";

export default function NotFound() {
  return (
    <main className="not-found-page">
      <header className="site-nav site-shell">
        <Link className="brand" href="/" aria-label="TokenOut home">
          <Image src="/assets/tokenout-symbol.png" alt="" width={32} height={32} />
          <span>TokenOut</span>
        </Link>
        <Link className="text-link" href="/">
          <ArrowLeft aria-hidden="true" />
          Back home
        </Link>
      </header>
      <section className="not-found-copy site-shell">
        <p className="eyebrow">Page not found</p>
        <h1>This limit does not exist.</h1>
        <p>The page may have moved, but TokenOut is still one click away.</p>
        <Link className="button" href="/">
          Return to TokenOut
        </Link>
      </section>
    </main>
  );
}
