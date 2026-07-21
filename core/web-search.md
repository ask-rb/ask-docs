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

## Quick Start

Get web search working end-to-end in 3 minutes:

```sh
# 1. Start SearXNG
docker run -d --name searxng -p 8888:8080 searxng/searxng

# 2. Install the MCP server
gem install ask-web-search-mcp

# 3. Verify it works standalone
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' |
  ask-web-search-mcp 2>/dev/null |
  grep ask_web_search && echo "✅ Server is working"
```

Then add it to your editor — see [With ZCode](#with-zcode) or
[With Claude Code](#with-claude-code) below. After restarting, the model
will have an `ask_web_search` tool it can call whenever it needs current
information.

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
Test it — this sends a `tools/list` request and prints the tool names:

```sh
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | ask-web-search-mcp
```

You should see `"name":"ask_web_search"` in the response. To run a real
search:

```sh
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"ask_web_search","arguments":{"query":"latest AI news"}}}' | ask-web-search-mcp
```

### With ZCode

Add to your ZCode user configuration (`~/.zcode/v2/config.json` or `~/.zcode/cli/config.json`):

```json
{
  "mcp": {
    "servers": {
      "ask-web-search-mcp": {
        "type": "stdio",
        "command": "ask-web-search-mcp",
        "args": []
      }
    }
  }
}
```

After restarting ZCode, the `ask_web_search` tool will be available
to the model automatically — no special prompts needed.

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
| Tool not found: `ask_web_search` | Using server with old client code | The tool name is `ask_web_search` — use that, not `web_search` |
| MCP servers not appearing in ZCode | Config in wrong file or format | Add `mcp.servers` to `~/.zcode/v2/config.json` (see [With ZCode](#with-zcode)) |

## What's next

- [MCP Client](/ask-docs/core/mcp) — connect your own Ruby app to any MCP server
- [Tools & Execution](/ask-docs/core/tools) — how tools work in the ask-rb ecosystem
- [The Agent Loop](/ask-docs/core/agent) — how the agent decides when to call
  `WebSearch` and what it does with the results

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
