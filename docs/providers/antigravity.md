# Antigravity provider — research findings (2026-07-17 spike)

App: Google Antigravity 2.1.4 (`com.google.antigravity`), VS Code fork. Verified on this Mac.

## Data locations

- `~/.antigravity` and `~/Library/Application Support/Antigravity` hold **no usage data**
  (extensions + Electron profile; auth is Keychain-encrypted leveldb — do not touch).
- **Canonical agent-data root: `~/.gemini/antigravity/`** (siblings `antigravity-ide` = stale
  mirror, `antigravity-backup` = ignore). Pick the most recently modified non-backup root.

## Usable signals

| Source | Format | Signal |
|---|---|---|
| `conversations/<uuid>.db` | SQLite (open read-only, URI `?immutable=1` — IDE holds WAL) | Active sessions. `gen_metadata`: one row per model generation → **turns**; `data` blob embeds readable model name ("Gemini 3.5 Flash (Low)") and ISO-8601 `created_at`; `size` ≈ serialized bytes → token estimate. |
| `conversations/<uuid>.pb` | protobuf | Legacy, frozen at 2026-05-19 migration — skip. |
| `brain/<uuid>/.system_generated/logs/transcript.jsonl` | JSONL | Clean per-step `created_at`/`type` — enrichment only (few convos have it). |
| `annotations/<uuid>.pbtxt` | protobuf text | `seconds:<unix>` = last-view time; cheap recency fallback. |

## Hard limits

- **No quota/rate-limit/tier state on disk anywhere** — enforced server-side, not mirrored.
  Provider therefore exposes `windows: []` and activity stats only.
- **No native token counts** — estimate (~4 bytes/token heuristic on blob size) and label as estimate.

## Provider strategy (implemented)

Scan `conversations/*.db` with mtime in the last 92 days → per DB read `gen_metadata`
(count, blob → first ISO date + model-shaped identifier, `size`) → bucket turns and
estimated tokens into today/week/daily history. When a row has no embedded timestamp,
the conversation DB modification date is used as an explicit approximation. Blob parsing
is a byte-scan (regex over lossy UTF-8), not full protobuf decoding — resilient to schema
drift and guarded against app-name false positives such as `Claude Switcher.app`.
