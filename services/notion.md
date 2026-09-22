---
layout: default
title: Notion
parent: Service Contexts
nav_order: 3
---



**Notion integration for AI agents.** The `ask-notion` gem is **deprecated and unsupported** — do not add it to new projects.

## Recommendation

Prefer Notion's official MCP server for agent access to Notion. It is the supported path for agents working with pages, databases, blocks, comments, and search, and it replaces `ask-notion` entirely.

## Legacy Integration (Unsupported)

`ask-notion` is documented here only for teams that already depend on it. It receives no maintenance, and its installation instructions are obsolete.

What it provided:

- An authenticated `Notion::Client` (`Ask::Notion.client`) over `notion-ruby-client`
- Context constants for system prompts (`DESCRIPTION`, `DOCS_URL`, `AUTH_NAME`)
- Structured error guidance (`Ask::Notion::Errors`) for common Notion API errors
- Credential resolution through `ask-auth`

### Legacy Client Usage

<!-- docs-example: not-verified -->
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

# Search and users
client.search(query: "project")
client.user_list
```

The client proxy converted `Notion::Api::Errors::Unauthorized` into `Ask::Auth::InvalidCredential`. Notion uses cursor-based pagination, which the client handled when given a block:

<!-- docs-example: not-verified -->
```ruby
all_pages = []
client.database_query(database_id: "abc123") do |page|
  all_pages.concat(page.results)
end
```

### Legacy Credentials

Existing installs resolved a Notion Internal Integration Secret via `ask-auth`: the `NOTION_TOKEN` environment variable or `~/.ask/credentials.yml` (`notion_token`). The token came from a Notion integration with the target pages/databases shared to it.

### Legacy Error Guidance

<!-- docs-example: not-verified -->
```ruby
# Guidance by exception class
Ask::Notion::Errors.for("Notion::Api::Errors::ObjectNotFound")
# => { message: "The requested page...", action: "Verify the ID..." }

# HTTP status meaning
Ask::Notion::Errors.status_code_description(429)
# => "Too Many Requests — Rate limit exceeded. Respect Retry-After header."

# Rate limits and pagination
Ask::Notion::Errors::RATE_LIMIT
# => { burst: "3 requests per second", sustained: "90 requests per minute", ... }
Ask::Notion::Errors::PAGINATION
# => { cursor_based: "Notion uses cursor-based pagination...", ... }
```

## Next Steps

- [Build custom tools](/ask-docs/extending/custom-tools)
- [Explore the agent loop](/ask-docs/core/agent)
