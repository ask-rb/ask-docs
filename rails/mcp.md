---
layout: default
title: Agent Integration (MCP)
parent: Rails Integration
nav_order: 5
---

# Agent Integration (MCP)

Connect coding agents to your Rails app so they can inspect your schema, query your database, and explore your code — all through the same tools `ask-rails-harness` uses internally.

This page covers:
- What ask-rails-harness-mcp is and why you'd use it
- How to set it up in your Rails app
- How to connect Claude Code, Cursor, and other agents
- How authentication and safety work
- How agents use each tool

## What is ask-rails-harness-mcp?

The [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) is an open standard for connecting AI agents to external tools. When you mount an MCP endpoint in your Rails app, any MCP-compatible coding agent can connect to it and discover your app's tools automatically.

ask-rails-harness already has 9 built-in tools for schema introspection, database queries, model inspection, route parsing, log reading, code search, file reading, and command execution. `ask-rails-harness-mcp` exposes these tools as MCP tools, so coding agents can use them without any manual configuration.

The agent connects to your app, discovers all available tools, and uses them to understand your codebase. This means:

```
Claude Code ──HTTP──> your-app.com/ask/mcp ──> live Rails introspection
```

### Why not just use a filesystem agent?

| Capability | Filesystem agent | ask-rails-harness-mcp |
|---|---|---|
| Read source code | ✅ Reads files | ✅ Reads files |
| Query database | ❌ Can't connect | ✅ Reads schema, runs queries |
| Understand schema | ❌ Reads schema.rb (stale) | ✅ Live schema via SchemaGraph |
| Inspect models | ❌ Raw file parsing | ✅ Structured model data |
| Read routes | ❌ Reads routes.rb (raw) | ✅ Parsed route table |
| Read logs | ❌ No access | ✅ Filtered log reading |
| Run commands | ✅ Shell access | ✅ Guarded command execution |

## Installation

```bash
bundle add ask-rails-harness-mcp
```

## Usage

### Option 1: stdio (local development — recommended)

Run from your Rails app root:

```bash
cd my-rails-app
ask-rails-harness-mcp
```

This boots your Rails app and starts an MCP stdio server. Configure in your agent's MCP config:

```json
{
  "mcp": {
    "servers": {
      "ask-rails-harness-mcp": {
        "type": "stdio",
        "command": "ask-rails-harness-mcp",
        "args": []
      }
    }
  }
}
```

### Option 2: HTTP endpoint (remote/production)

Mount in `config/routes.rb` behind your existing auth:

```ruby
Rails.application.routes.draw do
  authenticate :user, ->(u) { u.admin? } do
    post "ask/mcp", to: "ask/rails/mcp#handle"
  end
end
```

Then configure any MCP-compatible agent:

```json
{
  "mcp": {
    "servers": {
      "ask-rails-harness-mcp": {
        "type": "http",
        "url": "https://myapp.com/ask/mcp"
      }
    }
  }
}
```

## How coding agents use these tools

### Claude Code

```json
{
  "mcp": {
    "servers": {
      "ask-rails-harness-mcp": {
        "type": "stdio",
        "command": "ask-rails-harness-mcp"
      }
    }
  }
}
```

Now Claude Code can inspect your Rails app:
```
Claude > Show me the User model schema
Claude > How many users signed up this week?
Claude > What routes does the admin namespace have?
```

### Cursor

Same MCP config works in Cursor's MCP settings.

### Any MCP client

The tools are standard MCP tools — any MCP client can discover and call them:

```ruby
# Example: Connect from a Ruby script
require "ask/mcp"

client = Ask::MCP::Client.stdio("ask-rails-harness-mcp")
tools = client.list_tools
result = client.call_tool("schema_graph", { detail: "all" })
```

## Authentication

The MCP endpoint uses the same `Ask::Rails::Harness::Auth` system as the chat UI at `/ask`. If you don't configure auth, the endpoint is publicly accessible:

```ruby
Ask::Rails::Harness::Auth.check = -> {
  redirect_to main_app.login_path unless current_user&.admin?
}
```

## Safety

All ask-rails-harness safety features apply automatically because the tools are the same ones used by the chat UI:

- **Access modes** (configured via `Ask::Rails::Harness.configure`): `:read_only`, `:ask_before_changes`, `:full_access`
- **Command allowlists** — `allowed_commands` / `denied_commands` for the `RunCommand` tool
- **Write guards** — `INSERT`/`UPDATE`/`DELETE`/`DROP`/`ALTER` blocked by `QueryDatabase` in all environments
- **Audit log** — every tool call recorded in the `ask_audit_logs` table

## Available tools

| Tool | What it does |
|---|---|
| `schema_graph` | Full schema introspection — all models, tables, columns, associations, validations, indexes |
| `query_database` | Read-only SQL queries with safety guards |
| `read_model` | Introspect a single ActiveRecord model |
| `route_inspector` | Parsed route table with filters by controller or path |
| `read_log` | Read Rails log files with level/search filtering and rotated archive support |
| `search_codebase` | Full-text grep search across your codebase |
| `read_file` | Read any file relative to `Rails.root` |
| `run_command` | Run shell commands from app root (with allowlist) |
| `read_routes` | Read the raw `config/routes.rb` |

## Development

```bash
git clone https://github.com/ask-rb/ask-rails-harness-mcp.git
cd ask-rails-harness-mcp
bundle exec rake test
```

## Next Steps

- [Browse the database tools](/ask-docs/rails/database)
- [Configure error monitoring](/ask-docs/rails/errors)
- [Build custom tools](/ask-docs/extending/custom-tools)
