---
layout: default
title: Web Fetch
parent: Core Components
nav_order: 9
---

# Web Fetch

Fetch a URL and get clean, LLM-ready markdown. The ask-rb web fetch stack
is `ask-web-fetch` — a Ruby tool (`Ask::Tools::WebFetch`) with a pluggable
backend chain:

```
┌─────────────┐     ┌────────────────┐     ┌──────────────────────┐
│   Agent     │────▶│ ask-web-fetch  │────▶│ Crawl4AI (optional)  │
│  (tool call)│     │  backend chain │     │  localhost:11235     │
└─────────────┘     └───────┬────────┘     └───────────┬──────────┘
                            │                         │ headless Chromium,
                            │                         │ JS rendering, fit-markdown
                    ┌───────▼────────┐                │
                    │ Local (Ruby)   │──▶ HTML ───────┘
                    │ Net::HTTP+     │
                    │ Nokogiri+      │     ┌──────────────────────┐
                    │ reverse_md     │────▶│ Jina Reader (fallback)│
                    └────────────────┘     │  r.jina.ai, no key   │
                                           └──────────────────────┘
```

Same philosophy as [Web Search](web-search): **self-hosted where it matters,
no API keys for the core path, graceful fallbacks**.

## The backend chain

`Ask::Tools::WebFetch` tries each backend in order and returns the first
success:

1. **Crawl4AI** — when `CRAWL4AI_URL` is set. A self-hosted headless-Chromium
   renderer that executes JavaScript and returns clean fit-markdown, so it
   handles the SPA pages the Local backend can't. If the service is down or
   unreachable it fails fast and the chain falls through.
2. **Local** — pure Ruby (`Net::HTTP` + Nokogiri + reverse_markdown), zero
   dependencies: redirects, main-content extraction (`<article>` → `<main>`
   → `<body>`), chrome scrubbing, markdown tables and links.
3. **Jina** — Jina Reader free tier (`https://r.jina.ai/<url>`), no key for
   ~20 req/min per IP; the last-resort fallback.

Without Crawl4AI configured the chain is `Local, Jina` — no behavior change
for existing consumers. With `CRAWL4AI_URL` set it becomes
`Crawl4Ai, Local, Jina`.

## Quick Start

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

## Failure semantics

Every failure — network errors, timeouts, non-HTML responses, anti-bot
challenge pages, thin JS-shell extractions, auth errors (401/403) — raises
`Ask::WebFetch::Error` (`FetchError` hard failure, `EmptyContentError` page
fetched but nothing usable). The chain collects each backend's error and
returns a failure result listing them all, so callers know exactly what was
tried.

## Extending

Backends subclass `Ask::WebFetch::Backend`, implement `#fetch(url)`
returning `{ title:, content: }`, and register:

```ruby
Ask::Tools::WebFetch.backends = [MyBackend, Ask::WebFetch::Backends::Local]
```

Useful for tests (swap the chain) and for future self-hosted backends — the
same pattern as SearXNG in [Web Search](web-search).
