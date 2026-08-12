---
layout: default
title: Web Fetch
parent: Core Components
nav_order: 9
---

# Web Fetch

Fetch a URL and get clean, LLM-ready markdown. The ask-rb web fetch stack
is `ask-web-fetch` — a Ruby tool (`Ask::Tools::WebFetch`) with a pluggable
backend chain that tries each backend in order and returns the first
success:

```
┌─────────────┐     ┌───────────────────────────────────────────┐
│   Agent     │────▶│            ask-web-fetch                  │
│  (tool call)│     │            backend chain                  │
└─────────────┘     └───────┬───────────────────────────────────┘
                            │ tries in order, first success wins
                    ┌───────▼────────┐     ┌──────────────────────┐
                    │ Crawl4AI       │────▶│ Local (Ruby)         │
                    │ self-hosted,   │     │ httpx + Nokogiri     │
                    │ if CRAWL4AI_URL│     │ + content pruning    │
                    └───────┬────────┘     └───────────┬──────────┘
                            │                         │
                    ┌───────▼────────┐     ┌──────────▼──────────┐
                    │ Jina Reader   │────▶│ Browser (real Chrome)│
                    │ r.jina.ai     │     │ launched or attached │
                    │ free tier     │     │ Ferrum / CDP         │
                    └────────────────┘     └─────────────────────┘
```

Same philosophy as [Web Search](web-search): **self-hosted where it matters,
no API keys for the core path, graceful fallbacks** — and a last-resort
real browser for the sites nothing plain-HTTP can read.

## The backend chain

1. **Crawl4AI** — when `CRAWL4AI_URL` is set. A self-hosted headless-Chromium
   renderer that executes JavaScript and returns clean fit-markdown, so it
   handles the SPA pages the Local backend can't. If the service is down or
   unreachable it fails fast and the chain falls through.
2. **Local** — pure Ruby (`httpx` + Nokogiri + reverse_markdown), zero
   external services. One pooled keep-alive connection per thread, so
   repeated fetches cost a TLS handshake at most. Converts through the
   shared Markdown pipeline with a default adaptive `ContentFilter` (see
   [Content pruning](#content-pruning)), so the returned content is the
   density-scored "fit" of the page: chrome, navs, and link-farms pruned;
   article prose, tables, and code kept. A **JS-shell completeness signal**
   fails client-rendered apps through: if the server HTML shows a framework
   footprint (React/Vue/Next/Nuxt) or a big HTML page renders almost no
   text, Local reports the shell instead of silently returning a truncated
   page, and the chain moves to a rendering backend.
3. **Jina** — Jina Reader free tier (`https://r.jina.ai/<url>`), no key for
   ~20 req/min per IP; a last-resort fallback for JS-rendered pages.
4. **Browser** — real Chrome via Ferrum, appended when a Chrome/Chromium
   binary is found **or** `ASK_WEB_FETCH_CDP_URL` is set. Renders JavaScript
   and lets Cloudflare-style managed challenges that auto-solve complete
   themselves. Waits for real network idle (CDP Network events, so lazy
   SPAs render their later waves), and on a challenge page warms the domain
   root first — earning the clearance cookie in the persistent profile —
   then retries the URL once. Slowest, so it always sits last (see
   [Real Chrome (Browser)](#real-chrome-browser)).

With nothing else configured the chain is `Local, Jina` — no behavior change
for existing consumers. `CRAWL4AI_URL` adds Crawl4AI to the front; a Chrome
binary or `ASK_WEB_FETCH_CDP_URL` appends Browser to the back.

## Quick Start

<!-- docs-example: not-verified -->
```ruby
require "ask/web_fetch"

tool = Ask::Tools::WebFetch.new
result = tool.execute(url: "https://www.ruby-lang.org/en/")
puts result
# # Ruby Programming Language
# Source: https://www.ruby-lang.org/en/
# Ruby is a dynamic, open-source programming language...
```

Cap the output with `max_chars` (default 20000).

## Content pruning

`Local` and `Browser` convert through `Ask::WebFetch::Markdown` with an
adaptive `Ask::WebFetch::ContentFilter` — a density-based pruner ported from
crawl4ai's `PruningContentFilter` (Apache-2.0). Every element is scored on
text density, link density, semantic tag weight, class/id chrome penalty,
and text length; elements below an adaptive threshold are removed.
`preserve_classes` / `preserve_tags` whitelists keep specific content
regardless of score. Optional citations (`Markdown.generate(..., citations: true)`)
rewrite inline links as numbered `⟨N⟩` references.

## Self-hosted Crawl4AI

```sh
docker run -d --name crawl4ai -p 11235:11235 unclecode/crawl4ai:latest
```

```ruby
ENV["CRAWL4AI_URL"] = "http://localhost:11235"  # default when unset
ENV["CRAWL4AI_TOKEN"] = "..."                  # JWT-protected servers (0.9+)
```

The backend talks to the server's `POST /crawl` endpoint
(`{"urls": [...], "crawler_config": {"cache_mode": "bypass"}}`) and reads
`fit_markdown` (falling back to `raw_markdown`) plus `metadata.title`.

## Real Chrome (Browser)

Two modes, controlled by environment:

| Env var | Meaning |
|---|---|
| `ASK_WEB_FETCH_CHROME_PATH` | Path to a Chrome/Chromium binary (otherwise auto-detected) |
| `ASK_WEB_FETCH_PROFILE` | Persistent profile dir — keeps solved cookies across restarts |
| `ASK_WEB_FETCH_CDP_URL` | CDP endpoint of an already-running Chrome, e.g. `http://127.0.0.1:9222` |

- **Launched** (default when a binary is found): the backend starts its own
  headless Chrome. Handles SPAs and client-side pages, and lets managed
  challenges that auto-solve for real browsers complete themselves. A
  **warm-and-retry** pass handles the rest: on a challenge page it visits
  the domain root first (where the managed challenge auto-solves for a
  trusted browser), earning the domain's clearance cookie in the persistent
  profile, then retries the URL once — one warm per domain per process, one
  retry per fetch, so a DataDome-class wall still fails fast.
- **Attached** (`ASK_WEB_FETCH_CDP_URL`): drives a Chrome that is *already
  running* with `--remote-debugging-port` — the same connect-to-9222 pattern
  the chrome-devtools MCP uses. That browser is a **trusted context**: a
  long-lived profile with any cookies it has already earned (e.g.
  `cf_clearance`), so sites whose invisible challenges soft-block a fresh
  automation browser load normally. Each fetch uses its own tab, created and
  closed by the backend; existing tabs are never touched. The backend waits
  for real **network idle** (CDP Network events subscribed before
  navigation), so lazy SPAs render their later waves before the page is
  read — and on macOS the frontmost app gets its focus back when the tab
  closes.

Honest limitation, measured in the wild: freshly launched automation browsers
are soft-blocked by aggressive bot protection (patronview.com, npmjs.com,
stackoverflow.com never clear their challenge for a fresh profile, however
real the Chrome). The attached mode is the answer to those — run it against
a Chrome that has already solved the site once.

To use the MCP server through an attached browser:

```json
"ask-web-fetch-mcp": {
  "type": "stdio",
  "command": "ask-web-fetch-mcp",
  "args": [],
  "env": { "ASK_WEB_FETCH_CDP_URL": "http://127.0.0.1:9222" }
}
```

## Failure semantics

Every backend failure raises a subclass of `Ask::WebFetch::Error`:

| Error | Means | Retry? |
|---|---|---|
| `ParkedDomainError` | registrar parking ad (GoDaddy/Namecheap) — the domain is for sale, not a site | never |
| `EmptyContentError` | page fetched, nothing usable (JS shell, noise-only, empty) | no — re-render sometimes |
| `FetchError` | deterministic hard failure — 4xx, challenge page, non-HTML, auth | no |
| `TimeoutError` | network-level — timeout, refused, reset | yes |
| `ServerError` | service-side — Jina/Crawl4AI 5xx or rate limit | yes |

A registrar parking page is rejected on **every** backend (the shared
detector matches GoDaddy's parking-lander, Namecheap's parking app, and the
static registrar phrases in the raw HTML *and* in rendered markdown), so the
ad is never returned as the site's content.

When the whole chain fails, the tool collapses every backend's error into
one whose class carries the best explanation (`Ask::Tools::WebFetch.collapse`),
most definitive first: **`ParkedDomainError`** beats **`EmptyContentError`**
beats a deterministic **`FetchError`** (every backend failed dead), and any
transient failure in the mix keeps the retryable base **`Error`**. The
message still lists every backend and what it said, e.g.:

```
Error: WebFetch raised Ask::WebFetch::ParkedDomainError: all web fetch
backends failed for https://ayur.ai/ (Local: no readable content at ...;
Jina: Jina access error (403); Browser: parked domain at ... — registrar
parking page, not site content)
```

Clients read the class: the terminal verdicts are never retried, transient
failures recover on retry.

## Extending

Backends subclass `Ask::WebFetch::Backend`, implement `#fetch(url)`
returning `{ title:, content: }`, and register:

```ruby
Ask::Tools::WebFetch.backends = [MyBackend, Ask::WebFetch::Backends::Local]
```

Useful for tests (swap the chain) and for future self-hosted backends — the
same pattern as SearXNG in [Web Search](web-search).
