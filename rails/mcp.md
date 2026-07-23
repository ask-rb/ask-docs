---
layout: default
title: Agent Integration (MCP)
parent: Rails Integration
nav_order: 5
---

# Agent Integration (MCP)

Connect coding agents to your Rails app so they can inspect your schema, query your database, and explore your code — all through the same tools ask-rails uses internally.

This page covers:
- What ask-rails-mcp is and why you'd use it
- How to set it up in your Rails app
- How to connect Claude Code, Cursor, and other agents
- How authentication and safety work
- How agents use each tool

## What is ask-rails-mcp?

The [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) is an open standard for connecting AI agents to external tools. When you mount an MCP endpoint in your Rails app, any MCP-compatible coding agent can connect to it and discover your app's tools automatically.

Ask-rails already has 9 built-in tools for schema introspection, database queries, model inspection, route parsing, log reading, code search, file reading, and command execution. `ask-rails-mcp` exposes these tools as MCP tools, so coding agents can use them without any manual configuration.

The agent connects to your app, discovers all available tools, and uses them to understand your codebase. This means:

```
Claude Code ──HTTP──> your-app.com/ask/mcp ──> live Rails introspection
```

The agent doesn't read your source files — it calls SchemaGraph which runs live ActiveRecord reflection, and QueryDatabase which runs read-only SQL against your actual database.

## Why use this instead of letting the agent read files?

Coding agents that work at the filesystem level (reading `db/schema.rb`, grepping models) have limitations:

| Capability | Filesystem agent | ask-rails-mcp |
|---|---|---|
| Schema | Reads `db/schema.rb` (possibly stale) | Live reflection — always current |
| Associations | Parses `has_many` calls in Ruby files | Full graph incl. `through`, polymorphic |
| Database queries | Can't run queries | Read-only SQL with safety guards |
| Routes | Reads raw `routes.rb` | Parsed verb/path/controller/action |
| Logs | Can't access | Filtered log reading with rotated archive support |

If the agent can ask "what's the full schema?" and get back a complete model graph with columns, types, associations, and validations in one call, it understands your app much faster than reading files one at a time.

## Setup

Add to your Gemfile:

```ruby
gem "ask-rails-mcp"
```

Then mount the endpoint in `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  # Protect behind your existing auth
  authenticate :user, ->(u) { u.admin? } do
    post "ask/mcp", to: "ask/rails/mcp#handle"
  end
end
```

That's it. The endpoint is at `POST /ask/mcp` and speaks JSON-RPC over HTTP.

## Connecting an Agent

### Claude Code

Add to your `~/.claude/settings.json`:

```json
{
  "mcp": {
    "servers": {
      "ask-rails-mcp": {
        "type": "url",
        "url": "https://myapp.com/ask/mcp"
      }
    }
  }
}
```

Restart Claude Code. The agent will discover all 9 tools automatically. Try asking:

> "Map out the schema of my Rails app"
> "How is User connected to Order?"
> "Run a query to find users who signed up this week"

### Cursor

In Cursor's MCP configuration, add:

```json
{
  "mcpServers": {
    "ask-rails-mcp": {
      "type": "url",
      "url": "https://myapp.com/ask/mcp"
    }
  }
}
```

### Any MCP Client

The endpoint follows the standard MCP protocol over HTTP. Any MCP client that supports HTTP transport can connect. The initial `initialize` handshake returns all tool definitions with their JSON Schemas.

## Authentication

The MCP endpoint uses the same `Ask::Rails::Auth` system as the chat UI at `/ask`. If you don't configure auth, the endpoint is publicly accessible:

```ruby
# No auth — anyone can call tools
mount Ask::Rails::Engine, at: "/ask"
```

To protect it:

```ruby
Ask::Rails::Auth.check = -> {
  redirect_to main_app.login_path unless current_user&.admin?
}
```

Or use your routes file:

```ruby
authenticate :user, ->(u) { u.admin? } do
  post "ask/mcp", to: "ask/rails/mcp#handle"
end
```

## Safety

All ask-rails safety features apply automatically because the tools are the same ones used by the chat UI:

**Access modes** (configured via `Ask::Rails.configure`):

```ruby
config.environment :production do |env|
  env.mode = :read_only  # Blocks write/edit/bash/destroy tools
end
```

**Command allowlists** restrict what `RunCommand` can execute:

```ruby
config.allowed_commands = [/^rails /, /^git status/]
config.denied_commands = [/rm /, /dropdb/]
```

**Database write guards** reject any non-SELECT statement in all environments:

```
query_database(sql: "DROP TABLE users")
→ Error: Write statements (DROP) are rejected in all environments.
```

**Audit log** records every tool call made through the MCP endpoint in the `ask_audit_logs` table, just like calls made through the web UI.

## Available Tools

When an agent connects, it discovers these 9 tools:

### SchemaGraph

Full application schema introspection. Returns every model, table, column (with types and nullability), association (belongs_to, has_many, has_one, through, polymorphic), validation, and index.

Agents can answer:
- "What models exist and how are they related?"
- "Which models have polymorphic associations?"
- "What validations exist on the Payment model?"

### QueryDatabase

Run read-only SQL queries with automatic safety guards. Write statements are rejected. In production, only `SELECT` queries are allowed.

Agents can answer:
- "How many users signed up this week?"
- "What's the average order value?"

### ReadModel

Introspect a single ActiveRecord model — columns, associations, validators, and scopes.

Agents can answer:
- "What columns does the User model have?"
- "What validations are on the Order model?"

### RouteInspector

Returns the parsed route table — every route with its HTTP verb, path, controller, and action. Supports filtering by controller name or path pattern.

Agents can answer:
- "What routes exist for the users controller?"
- "Show me all admin routes"

### ReadLog

Read Rails log files with level filtering and search. Automatically handles rotated log archives.

Agents can answer:
- "Show me the last 50 errors"
- "Search the log for timeout errors"

### SearchCodebase

Full-text search of the codebase using grep. Skips `.git` and `node_modules` automatically.

### ReadFile

Read any file relative to `Rails.root`. Returns content and size.

### RunCommand

Run shell commands in the Rails application root directory. Subject to configured command allowlists.

### ReadRoutes

Read the raw `config/routes.rb` file. Use RouteInspector instead for structured route data.

## What the Agent Can Do

With these 9 tools, an MCP-connected agent can:

- **Map the full schema** and understand how models relate to each other
- **Query the database** to find records, count aggregations, or debug data issues
- **Inspect models** to understand columns, validations, and associations
- **Read the route table** to understand the API surface
- **Search the codebase** for specific patterns
- **Read files** to understand implementation details
- **Run commands** for deployments, test runs, or maintenance tasks

All through the MCP endpoint — the agent never needs SSH access or a Rails console.

## Development

```bash
git clone https://github.com/ask-rb/ask-rails-mcp.git
cd ask-rails-mcp
bundle install
bundle exec rake test
```
