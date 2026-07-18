# TokenOut analytics

TokenOut measures four separate stages. Keep them separate when reporting because they answer different questions.

| Metric | Source | Meaning |
|---|---|---|
| Visitors and page views | Vercel Web Analytics | Anonymous visits to the marketing site, including pages and referrers. |
| Download requests | Vercel custom event `Download Requested` | A visitor followed a TokenOut download link. The `placement` property identifies the button. |
| Completed DMG downloads | GitHub release asset `download_count` | GitHub served a release asset. Repeat downloads and automated traffic can be included. |
| App installs | Vercel custom event `App Installed` | The app reached its first successful launch and delivered the anonymous event. Reinstalling after deleting preferences can count again. |

The app install event contains only:

- TokenOut version
- build number
- macOS version
- processor architecture (`arm64` or `x86_64`)

It does not contain a device identifier, account identifier, provider data, prompts, filenames, token history, cost history, credentials, or rate-limit values.

## Dashboards

Open the TokenOut project in Vercel and use **Web Analytics** for visitors, referrers, `Download Requested`, and `App Installed`. Vercel custom events require a Vercel plan that supports them; anonymous page-view analytics and GitHub asset counts remain useful without custom events.

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
5. Confirm a clean first app launch creates one `App Installed` event.
