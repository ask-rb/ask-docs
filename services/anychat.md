---
layout: default
title: Anychat
parent: Service Contexts
nav_order: 9
---



**Anychat API client for the ask-rb ecosystem.** Creates and manages the agents
an Anychat workspace owns. Anychat gives a business an agent of its own — a page
customers can visit, a chat they can talk to, and the words it answers with.
This gem is the HTTP client layer; tool framing (MCP servers, native `Ask::Tools`)
is provided by consumers.

```ruby
gem "ask-anychat"
```

## Quick Start

<!-- docs-example: not-verified -->
```ruby
require "ask-anychat"

client = Ask::AnyChat.client

# List all agents in a workspace
client.workspace_agents("anywaye")
# => [{"handle"=>"support", "display_name"=>"Support", "public"=>true, ...}]

# Fetch one agent by its handle
client.workspace_agent("anywaye", "support")

# Create a new agent
client.create_workspace_agent("anywaye", display_name: "Support")

# Update an existing agent
client.update_workspace_agent("anywaye", "support", display_name: "Help desk")

# Delete an agent (frees the address)
client.destroy_workspace_agent("anywaye", "support")

# List the sources an agent may read
client.agent_sources("anywaye", "support")
# => [{"handle"=>"website", "kind"=>"site", "name"=>"Example", ...}]

# Read one page from a source, as clean markdown
page = client.agent_source_page("anywaye", "support", "website", "/pricing")
page["content"]  # => "# Pricing\n\nPlans start at $9/mo."
```

## Authentication

The client resolves your API token via `Ask::Auth.resolve(:anychat_token)`.
Tokens can be provided through any configured provider:

1. **Environment variable:** `ANYCHAT_TOKEN`
2. **Credentials file:** `~/.ask/credentials.yml`
3. **Rails credentials:** `Rails.application.credentials.anychat_token`

Mint a token in the Anychat app under **Settings → API tokens**.

## Client

`Ask::AnyChat.client` returns a Faraday-backed HTTP client configured with:

- JSON request/response middleware
- Retry middleware — 3 retries on 429, 500, 502, 503 with 0.5s interval
- Open timeout: 10s, read timeout: 30s (configurable)
- Authorization header set from the resolved token

The base URL defaults to `https://anywaye.com`. Override it with
`ENV["ANYCHAT_BASE_URL"]` or pass `base_url:` to the client.

```ruby
client = Ask::AnyChat.client(base_url: "https://my-instance.example.com")
```

## Agent Shape

All read methods return hashes with this shape:

```ruby
{
  "handle"       => "support",
  "display_name" => "Support",
  "description"  => "Answers customer questions",
  "public"       => true,
  "address"      => "/anywaye/support"
}
```

The `handle` is the URL-safe address the agent answers on within a workspace.
The `address` is the full path customers visit.

## Source Shape

Source hashes returned by `agent_sources` and `agent_source`:

```ruby
{
  "handle"         => "website",
  "kind"           => "site",
  "name"           => "Example",
  "address"        => "/anywaye/support/website",
  "excluded_paths" => []
}
```

The `kind` is `"site"` for a connected website or `"corpus"` for an uploaded
knowledge base. The `address` is the full path the agent reads from.

## API

| Method | HTTP | Path | Description |
|--------|------|------|-------------|
| `workspace_agents(workspace)` | GET | `/api/v1/workspaces/{workspace}/agents` | List all agents, oldest first |
| `workspace_agent(workspace, handle)` | GET | `/api/v1/workspaces/{workspace}/agents/{handle}` | Fetch one agent |
| `create_workspace_agent(workspace, **attrs)` | POST | `/api/v1/workspaces/{workspace}/agents` | Create an agent |
| `update_workspace_agent(workspace, handle, **attrs)` | PATCH | `/api/v1/workspaces/{workspace}/agents/{handle}` | Update an agent |
| `destroy_workspace_agent(workspace, handle)` | DELETE | `/api/v1/workspaces/{workspace}/agents/{handle}` | Delete an agent |
| `agent_sources(workspace, agent)` | GET | `.../agents/{agent}/sources` | List sources an agent reads |
| `agent_source(workspace, agent, source)` | GET | `.../agents/{agent}/sources/{source}` | Show one source and its grant |
| `agent_source_pages(workspace, agent, source)` | GET | `.../agents/{agent}/sources/{source}/pages` | List pages in a source |
| `agent_source_page(workspace, agent, source, ref)` | GET | `.../agents/{agent}/sources/{source}/pages/{ref}` | Read one page as markdown |
| `agent_source_search(workspace, agent, source, q)` | GET | `.../agents/{agent}/sources/{source}/search` | Search pages in a source |

**Create attributes:**

| Attribute | Required | Notes |
|-----------|----------|-------|
| `display_name` | Yes | Human-readable name |
| `handle` | No | URL-safe address (3–32 chars). Auto-derived from name if omitted |
| `description` | No | One-liner about the agent |
| `public` | No | Whether customers can see it (default: true) |

**Update attributes:** Same as create, but all optional. Only passed attributes
are written — omitting an attribute preserves its current value.

## Error Guide

All errors inherit from `Ask::AnyChat::Error`:

| Error | HTTP | Meaning |
|-------|------|---------|
| `Error::Unauthorized` | 401 | Token missing, expired, or refused |
| `Error::NotFound` | 404 | No such workspace or agent |
| `Error::Invalid` | 422 | Request understood and refused; `message` explains why |
| `Error::Api` | other | Server failure or unexpected response |
| `Error::Unreachable` | — | API could not be reached at all |

Every error carries the human-readable sentence from the API response:

```ruby
begin
  client.workspace_agent("anywaye", "nonexistent")
rescue Ask::AnyChat::Error::NotFound => e
  e.message  # => "No agent with that handle in this workspace."
end
```

## Context Constants

Used in system prompts to inform AI agents about Anychat capabilities:

```ruby
Ask::AnyChat::DESCRIPTION  # => "Anychat gives a business an agent of its own..."
Ask::AnyChat::DOMAIN_URL   # => "https://anywaye.com"
Ask::AnyChat::DOCS_URL     # => "https://anywaye.com/docs/api"
Ask::AnyChat::AUTH_NAME    # => :anychat_token
Ask::AnyChat::API_VERSION  # => "v1"
Ask::AnyChat::QUICK_START  # => (copy-pasteable Ruby snippet)
```

## Development

```bash
bundle install
bundle exec rake test
bundle exec rake coverage  # with SimpleCov
```

## Dependencies

- **Runtime:** `ask-auth >= 0.3.2`, `faraday ~> 2.0`, `faraday-retry ~> 2.0`

## Source

- GitHub: [github.com/ask-rb/ask-anychat](https://github.com/ask-rb/ask-anychat)
- RubyGems: [rubygems.org/gems/ask-anychat](https://rubygems.org/gems/ask-anychat)

## Next Steps

- [Anychat MCP tools](/ask-docs/services/anychat_mcp) — expose agents to LLMs via MCP
- [Build custom tools](/ask-docs/extending/custom-tools)
- [Learn about credentials](/ask-docs/core/auth)
