---
layout: default
title: Web Search
parent: Core Components
nav_order: 8
---

# Web Search

Search the web from your agent. The ask-rb web search stack runs a local
[SearXNG](https://docs.searxng.org/) instance — a privacy-respecting,
self-hosted metasearch engine — and exposes it as both a Ruby tool library
and an MCP server.

```
┌─────────────┐     ┌───────────────┐     ┌──────────────┐
│  MCP Client  │────▶│ask-web-search │────▶│   SearXNG    │
│ (ZCode,CC,   │     │    -mcp       │     │  localhost   │
│  Cursor)     │◀────│  (stdio MCP)  │◀────│   :8888      │
└─────────────┘     └───────────────┘     └──────┬───────┘
                                                 │
                                          ┌──────┴───────┐
                                          │  DuckDuckGo   │
                                          │  Wikipedia    │
                                          │  (more)       │
                                          └──────────────┘
```

This means **no API keys, no third-party search services, no rate limits**.
Your searches stay on your machine.

## Prerequisites

A running SearXNG instance. The default endpoint is `http://localhost:8888`.

```sh
docker run -d --name searxng -p 8888:8080 searxng/searxng
```

Or use the provided Docker Compose setup:

```yaml
# docker-compose.yml
services:
  core:
    image: searxng/searxng:latest
    ports:
      - "8888:8080"
    volumes:
      - ./core-config/:/etc/searxng/
    environment:
      - SEARXNG_PORT=8888
```

<details markdown="block">
<summary>Settings notes for local use</summary>

Minimal `settings.yml` for a local-only instance:

```yaml
server:
  secret_key: "change_this_to_something_random"
  bind_address: "0.0.0.0"
  port: 8888
  limiter: false

search:
  safe_search: 0
  formats:
    - html
    - json

engines:
  - name: duckduckgo
    engine: duckduckgo
  - name: wikipedia
    engine: wikipedia
```

Enable `json` in `search.formats` — the tool library and MCP server
both use the JSON API.
</details>

## The Tool Library: `ask-web-search`

[`ask-web-search`](https://github.com/ask-rb/ask-web-search) wraps SearXNG's JSON
API into an `Ask::Tools::WebSearch` tool that any ask-rb agent can call.

### Installation

```ruby
gem "ask-web-search"
```

### Usage

```ruby
require "ask/web_search"

tool = Ask::Tools::WebSearch.new
result = tool.execute(query: "ruby programming language")
puts result
# => 1. Ruby Programming Language
#    https://www.ruby-lang.org/en/
#    Ruby is a dynamic, open-source programming language…
#
#    2. Ruby (programming language) - Wikipedia
#    https://en.wikipedia.org/wiki/Ruby_(programming_language)
#    Ruby is a general-purpose programming language…
```

### With ask-agent

```ruby
session = Ask::Agent::Session.new(
  model: "gpt-4o",
  tools: [Ask::Tools::WebSearch]
)

session.run("Find recent news about SpaceX")
```

The agent will call `WebSearch` whenever it needs current information,
just like any other tool.

### Output format

Results are formatted as numbered entries with title, URL, and content
snippet — designed for LLM consumption, not human browsing:

```
1. Title
   https://example.com
   Content snippet here…

2. Next Title
   https://example.org
   Next content…
```

If no results are found, the tool returns `"No results found."`.

### Configuration

Set the SearXNG URL via environment variable:

```sh
export SEARXNG_URL=http://localhost:8888
```

Or in Ruby:

```ruby
Ask::Tools::WebSearch.searxng_url = "http://localhost:8888"
```

Defaults to `http://localhost:8888`.

## The MCP Server: `ask-web-search-mcp`

[`ask-web-search-mcp`](https://github.com/ask-rb/ask-web-search-mcp) wraps the
same tool as a stdio-based [MCP](https://modelcontextprotocol.io/) server.
This lets **any MCP client** — ZCode, Claude Code, Cursor, Codex — use your
local SearXNG for web searches without knowing anything about the ask-rb
ecosystem.

### Installation

```sh
gem install ask-web-search-mcp
```

This installs the `ask-web-search-mcp` executable on your PATH.

### Usage (standalone)

```sh
ask-web-search-mcp
```

The server reads JSON-RPC messages on stdin and writes responses to stdout.
Test it:

```sh
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}
{"jsonrpc":"2.0","id":2,"method":"notifications/initialized","params":{}}
{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}
{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"web_search","arguments":{"query":"latest AI news"}}}' | ask-web-search-mcp
```

### With ZCode (Desktop)

1. Open **Settings → MCP Servers**
2. Click **"New MCP Server"**
3. Fill in the form:
   - **Scope**: `User` (available in all workspaces)
   - **Name**: `ask-web-search-mcp`
   - **Transport**: `stdio`
   - **Command**: `ask-web-search-mcp`
   - **Args**: *(leave empty)*
4. Click **Save**

Or switch to **Full configuration mode** and paste:

```json
{
  "ask-web-search-mcp": {
    "type": "stdio",
    "command": "ask-web-search-mcp",
    "args": []
  }
}
```

After saving, ZCode will connect to the server and the `ask_web_search`
tool will be available to the model automatically.

### With Claude Code

```sh
claude mcp add ask-web-search-mcp -- ask-web-search-mcp
```

### Configuration

The MCP server inherits configuration from `ask-web-search`:

```sh
export SEARXNG_URL=http://localhost:8888
export DEBUG=1               # enable MCP debug logging to stderr
```

## Choosing your path

| You want to… | Use |
|---|---|
| Call web search from Ruby code | `ask-web-search` gem |
| Add web search to an ask-rb agent | `Ask::Tools::WebSearch` tool |
| Give ZCode/Claude Code web search | `ask-web-search-mcp` MCP server |
| Just run SearXNG | Docker Compose in the [`searxng/`](https://github.com/ask-rb/ask-web-search-mcp) directory |

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Errno::ECONNREFUSED` | SearXNG not running | `docker compose up -d` in the `searxng/` directory |
| Empty results | SearXNG can't reach upstream | Check network / SearXNG logs: `docker logs searxng-core` |
| MCP server not connecting | Not installed or not on PATH | `gem install ask-web-search-mcp` then `which ask-web-search-mcp` |
| `LoadError: cannot load such file` | Missing dependency | `gem install ask-web-search ask-mcp` |
| SearXNG returns HTML not JSON | `json` format not enabled | Add `formats: [html, json]` to `settings.yml` |

## How it all fits together

```
ask-web-search-mcp  ──── depends on ───▶  ask-mcp
  (MCP server)                           (MCP protocol)

ask-web-search-mcp  ──── depends on ───▶  ask-web-search
                                          (tool library)

ask-web-search     ──── depends on ───▶  ask-tools
                                          (tool framework)

ask-web-search     ──── calls ─────────▶  SearXNG JSON API
                                          (localhost:8888)

SearXNG            ──── proxies ──────▶  DuckDuckGo, Wikipedia, etc.
```

No gem in the tool chain depends on Rails, ActiveRecord, or any web
framework. You can use web search in a 5-line script or inside a full
Rails application — it works the same either way.
