---
layout: default
title: "Anychat MCP"
parent: Service Contexts
nav_order: 10
---



**MCP server for Anychat.** Exposes a workspace's agents, sources, and pages as
callable tools over stdio — list agents, create one, manage what it reads, browse
its pages, or search through them. Built on `ask-mcp` and `ask-anychat`. Designed
for clients that speak MCP: ZCode, Claude Code, Cursor, and the like.

```ruby
gem "ask-anychat-mcp"
```

## Quick Start

```bash
# Install the gem
gem install ask-anychat-mcp

# Set your API token
export ANYCHAT_TOKEN=your-token-here

# Run the MCP server (blocks on stdin/stdout)
ask-anychat-mcp
```

Register it with your MCP client:

```json
{
  "mcp": {
    "servers": {
      "ask-anychat-mcp": {
        "type": "stdio",
        "command": "ask-anychat-mcp",
        "env": { "ANYCHAT_TOKEN": "..." }
      }
    }
  }
}
```

## How It Works

The gem follows a clean two-layer design:

```
ask-mcp              Protocol layer — JSON-RPC over stdio, tool dispatch
ask-anychat-mcp      Tool shell — name, schema, call for each operation
ask-anychat          HTTP client — Faraday calls to the Anychat REST API
```

`ask-anychat-mcp` depends on both `ask-mcp` (>= 0.5.0) and `ask-anychat`
(>= 0.1.0). It wires ten tools into `Ask::MCP::Server.start_stdio` and
delegates to the HTTP client. You never touch Faraday or the REST API directly.

## Tools

All tools require a `workspace` argument (the workspace username). Tool
names are prefixed `ask_anychat_` to avoid collisions with other MCP tools.

### `ask_anychat_list_agents`

List every agent a workspace owns, oldest first.

| Argument | Required | Description |
|----------|----------|-------------|
| `workspace` | Yes | Workspace username |

Returns human-readable lines:

```
Support at /anywaye/support -- Answers customer questions (public)
Billing at /anywaye/billing -- Handles invoices (private)
```

Or: `This workspace has no agents yet.`

### `ask_anychat_get_agent`

Fetch one agent by the address it answers on.

| Argument | Required | Description |
|----------|----------|-------------|
| `workspace` | Yes | Workspace username |
| `agent` | Yes | Agent handle (e.g. `support`) |

Returns display name, address, description (if any), and public/private status.

### `ask_anychat_create_agent`

Create a new agent. The API derives the handle from the name if you don't
provide one, and hands you a free variant if the preferred one is taken.

| Argument | Required | Description |
|----------|----------|-------------|
| `workspace` | Yes | Workspace username |
| `display_name` | Yes | Human-readable name |
| `handle` | No | URL-safe address (3–32 chars) |
| `description` | No | One-liner about the agent |
| `public` | No | Whether customers can see it |

Returns: `Created Support at /anywaye/support.`

### `ask_anychat_update_agent`

Update an existing agent. Only the arguments you pass are written — omitting
an argument preserves its current value.

| Argument | Required | Description |
|----------|----------|-------------|
| `workspace` | Yes | Workspace username |
| `agent` | Yes | Which agent to change (the current handle) |
| `display_name` | No | New display name |
| `handle` | No | Move the agent to a new address |
| `description` | No | New description |
| `public` | No | New visibility |

Note the distinction: `agent` is which one to change; `handle` is where to
move it. These are two different concepts.

Returns: `Updated Support at /anywaye/support.`
Or: `Error: nothing to change.`

### `ask_anychat_delete_agent`

Retire an agent. The address becomes free for reuse.

| Argument | Required | Description |
|----------|----------|-------------|
| `workspace` | Yes | Workspace username |
| `agent` | Yes | Agent handle to delete |

Returns: `Retired the agent at /anywaye/support. The address is free again.`

### `ask_anychat_list_sources`

List the sources an agent may read — websites the workspace connected or corpora
it holds.

| Argument | Required | Description |
|----------|----------|-------------|
| `workspace` | Yes | Workspace username |
| `agent` | Yes | Agent handle |

Returns human-readable lines:

```
Example at /anywaye/support/website (site)
Documentation at /anywaye/support/docs (corpus) — set aside: /internal
```

Or: `This agent has no sources yet.`

### `ask_anychat_get_source`

Show one source an agent reads, by the handle `list_sources` returns.

| Argument | Required | Description |
|----------|----------|-------------|
| `workspace` | Yes | Workspace username |
| `agent` | Yes | Agent handle |
| `source` | Yes | Source handle (e.g. `website`) |

Returns name, kind, address, and which pages were set aside.

### `ask_anychat_browse_pages`

List every page an agent may read in a source — the manifest — with set-aside
pages already left out.

| Argument | Required | Description |
|----------|----------|-------------|
| `workspace` | Yes | Workspace username |
| `agent` | Yes | Agent handle |
| `source` | Yes | Source handle |

Returns:

```
2 pages:
/pricing — Pricing
/features — Features
```

Or: `This source has no pages yet.`

### `ask_anychat_read_page`

Read one page an agent may read, by its reference, as clean markdown.

| Argument | Required | Description |
|----------|----------|-------------|
| `workspace` | Yes | Workspace username |
| `agent` | Yes | Agent handle |
| `source` | Yes | Source handle |
| `reference` | Yes | Page path (e.g. `/pricing`) |

Returns the page title and markdown content:

```
Pricing

# Pricing

Plans start at $9/mo.
```

### `ask_anychat_search_pages`

Search the pages an agent may read in a source. Returns references, titles,
and snippets — read one by reference for the whole page.

| Argument | Required | Description |
|----------|----------|-------------|
| `workspace` | Yes | Workspace username |
| `agent` | Yes | Agent handle |
| `source` | Yes | Source handle |
| `query` | Yes | What to look for |

Returns:

```
/pricing — Pricing: Plans start at...
```

Or: `Nothing found for pricing.`

## Configuration

| Variable | Required | Default | Purpose |
|----------|----------|---------|---------|
| `ANYCHAT_TOKEN` | Yes | — | API token from Settings → API tokens |
| `ANYCHAT_BASE_URL` | No | `https://anywaye.com` | Override for self-hosted instances |
| `DEBUG` | No | `off` | Set to `1` to enable debug logging |

## Error Handling

Every tool catches `Ask::AnyChat::Error` and returns a human-readable error
string instead of raising. Your MCP client never sees a crash — it sees
`Error: No agent with that handle in this workspace.`

The error hierarchy:

| Error | Meaning |
|-------|---------|
| `Error::Unauthorized` | Token missing or refused |
| `Error::NotFound` | No such workspace or agent |
| `Error::Invalid` | Request refused (details in message) |
| `Error::Api` | Server failure |
| `Error::Unreachable` | API could not be reached |

## Using from Ruby

If you'd rather call the tools programmatically instead of running the stdio
server:

```ruby
require "ask-anychat-mcp"
require "ask-anychat"

client = Ask::AnyChat.client
tools = Ask::AnyChat::MCP.tools(client: client)

# Each tool responds to name, description, params_schema, and call
tools.each do |tool|
  puts "#{tool.name}: #{tool.description}"
end

# Call a tool directly
result = tools.find { |t| t.name == "ask_anychat_list_agents" }
result.call("workspace" => "anywaye")
# => "Support at /anywaye/support -- Answers questions (public)\n..."
```

## Development

```bash
bundle install
bundle exec rake test
```

The test suite uses a `FakeClient` that records calls without touching the
network. Integration tests spawn the server as a real subprocess and verify
the full MCP protocol handshake.

## Dependencies

- **Runtime:** `ask-anychat >= 0.1.0`, `ask-mcp >= 0.5.0`

## Source

- GitHub: [github.com/ask-rb/ask-anychat-mcp](https://github.com/ask-rb/ask-anychat-mcp)
- RubyGems: [rubygems.org/gems/ask-anychat-mcp](https://rubygems.org/gems/ask-anychat-mcp)

## Next Steps

- [Anychat API client](/ask-docs/services/anychat) — the HTTP layer underneath
- [MCP client and server](/ask-docs/core/mcp) — the protocol layer
- [Build custom tools](/ask-docs/extending/custom-tools)
