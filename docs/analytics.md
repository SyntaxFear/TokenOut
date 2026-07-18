# TokenOut analytics

TokenOut measures three separate stages, all on the website side — the app itself sends nothing. Keep them separate when reporting because they answer different questions.

| Metric | Source | Meaning |
|---|---|---|
| Visitors and page views | Vercel Web Analytics | Anonymous visits to the marketing site, including pages and referrers. |
| Download requests | PostHog event `download_requested` | A visitor followed a TokenOut download link. The `placement` property identifies the button. |
| DMG download count | GitHub release asset `download_count` | GitHub recorded an asset download request. Repeat downloads and automated traffic can be included. |

## Dashboards

Open the TokenOut project in Vercel and use **Web Analytics** for visitors and referrers. Open PostHog for the `download_requested` counts (per placement).

Create a PostHog project, then configure these Vercel environment variables for Production and Preview:

```sh
POSTHOG_PROJECT_TOKEN=phc_your_project_token
POSTHOG_HOST=https://us.i.posthog.com
```

Use `https://eu.i.posthog.com` instead if the project is hosted in PostHog EU. TokenOut sends events through its own server, disables person-profile creation, and generates a new random identifier for every event. No PostHog browser SDK, cookies, autocapture, or session replay are used.

Until `POSTHOG_PROJECT_TOKEN` is configured, `download_requested` events are logged to the deployment console only.

For a quick live JSON report of completed downloads, open:

```text
https://tokenout.scrubmac.app/api/analytics/downloads
```

Use GitHub's release asset API for completed download totals:

```sh
gh api repos/SyntaxFear/TokenOut/releases \
  --jq '.[] | {tag: .tag_name, published: .published_at, assets: [.assets[] | {name, download_count}]}'
```

The stable `TokenOut.dmg` asset and the versioned asset are separate counters. Add them together only if both point to the same release build and both are publicly offered.

## Launch checks

Before announcing a release:

1. Publish the GitHub release with both `TokenOut.dmg` and the versioned DMG.
2. Confirm `https://tokenout.scrubmac.app/download` redirects to a successful GitHub asset response.
3. Confirm the production site, `/robots.txt`, `/sitemap.xml`, and `/appcast.xml` return `200`.
4. Confirm the Vercel Web Analytics dashboard receives a page view.
