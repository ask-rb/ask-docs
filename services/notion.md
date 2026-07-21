---
layout: default
title: Notion
parent: Service Contexts
nav_order: 3
---



**Notion service context for the ask-rb ecosystem.** Provides an authenticated Notion API client,
context metadata, and structured error guidance for AI agents.

```ruby
gem "ask-notion"
```

## Quick Start

```ruby
require "ask-notion"

client = Ask::Notion.client
client.database_query(database_id: "your-database-id")
client.page_retrieve(page_id: "your-page-id")
client.search(query: "project notes")
```

## Context Metadata

Available constants for AI system prompts:

| Constant | Value |
|----------|-------|
| `Ask::Notion::DESCRIPTION` | "Notion — pages, databases, blocks, comments, users, search" |
| `Ask::Notion::DOCS_URL` | <https://developers.notion.com/> |
| `Ask::Notion::API_REF_URL` | <https://developers.notion.com/reference> |
| `Ask::Notion::AUTH_NAME` | `:notion_token` |
| `Ask::Notion::AUTH_HOW` | Create an integration at <https://www.notion.so/my-integrations> |
| `Ask::Notion::GEM_NAME` | `notion-ruby-client` |
| `Ask::Notion::GEM_VERSION` | `~> 1.2` |
| `Ask::Notion::GEM_DOCS` | <https://www.rubydoc.info/gems/notion-ruby-client> |
| `Ask::Notion::QUICK_START` | Ruby code snippet with common client calls |

## Client

`Ask::Notion.client` returns an authenticated `Notion::Client`:

```ruby
client = Ask::Notion.client

# Databases
client.database_query(database_id: "abc123", filter: { ... }, sorts: [...])

# Pages
client.page_retrieve(page_id: "abc123")
client.page_create(parent: { database_id: "abc123" }, properties: { ... })
client.page_update(page_id: "abc123", properties: { ... })

# Blocks
client.block_children_list(block_id: "abc123")
client.append_block_children(block_id: "abc123", children: [...])

# Search
client.search(query: "project")

# Users
client.user_list
client.user_retrieve(user_id: "abc123")
```

The client proxy converts authentication errors (`Notion::Api::Errors::Unauthorized`) into
`Ask::Auth::InvalidCredential` for consistent error handling.

## Error Guide

`Ask::Notion::Errors` provides structured knowledge for agents:

```ruby
# Look up guidance by exception class
Ask::Notion::Errors.for("Notion::Api::Errors::ObjectNotFound")
# => { message: "The requested page...", action: "Verify the ID..." }

# HTTP status code descriptions
Ask::Notion::Errors.status_code_description(429)
# => "Too Many Requests — Rate limit exceeded. Respect Retry-After header."

# Rate limit info
Ask::Notion::Errors::RATE_LIMIT
# => { burst: "3 requests per second", sustained: "90 requests per minute", ... }

# Pagination info
Ask::Notion::Errors::PAGINATION
# => { cursor_based: "Notion uses cursor-based pagination...", ... }
```

## Authentication

Set your Notion Internal Integration Secret:

```bash
export NOTION_TOKEN="ntn_your_integration_token"
```

Or add it to `~/.ask/credentials.yml`:

```yaml
notion_token: ntn_your_integration_token
```

### Setting up a Notion Integration

1. Go to [Notion Integrations](https://www.notion.so/my-integrations)
2. Create a new integration and copy the "Internal Integration Secret"
3. In Notion, share the pages/databases you want the integration to access
4. Set the token as described above

## Pagination

Notion uses cursor-based pagination. The client handles this automatically when you supply a block:

```ruby
all_pages = []
client.database_query(database_id: "abc123") do |page|
  all_pages.concat(page.results)
end
```

## Dependencies

- **Runtime:** `ask-auth ~> 0.1`, `notion-ruby-client ~> 1.2`
- **Development:** minitest, mocha, rake

## Links

- **Source:** [github.com/ask-rb/ask-notion](https://github.com/ask-rb/ask-notion)
- **Issues:** [github.com/ask-rb/ask-notion/issues](https://github.com/ask-rb/ask-notion/issues)
- **API Docs:** [developers.notion.com](https://developers.notion.com/)
- **RubyGems:** [rubygems.org/gems/ask-notion](https://rubygems.org/gems/ask-notion)

## Next Steps

- [Build custom tools](/ask-docs/extending/custom-tools)
- [Explore the agent loop](/ask-docs/core/agent)
