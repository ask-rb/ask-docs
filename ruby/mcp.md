---
layout: default
title: Agent Integration (MCP)
parent: Ruby Harness
nav_order: 4
---

# Agent Integration (MCP)

Connect coding agents to **any Ruby project** — gems, Sinatra apps, plain
scripts — so they can query the database, inspect models, read logs, run
guarded commands, and run tests with structured results.

## What is ask-ruby-harness-mcp?

[The Model Context Protocol (MCP)](https://modelcontextprotocol.io/) is an
open standard for connecting AI agents to external tools. `ask-ruby-harness-mcp`
exposes the six ask-ruby-harness tools as MCP tools over stdio, so any
MCP-compatible coding agent (Claude Code, Cursor, ZCode, ...) can use them
without manual configuration.

The server serves the project in **its working directory** — start it from
the project root you want it to manage. There is no Rails boot and no app
code to load; the tools connect to the database lazily only when used.

## Installation

```bash
gem install ask-ruby-harness-mcp
```

or add to your Gemfile (if you bundle it with the project):

```ruby
gem "ask-ruby-harness-mcp"
```

## Usage

Run from your project root:

```bash
cd my-ruby-project
ask-ruby-harness-mcp
```

Configure in your agent's MCP config:

```json
{
  "mcp": {
    "servers": {
      "ask-ruby-harness-mcp": {
        "type": "stdio",
        "command": "ask-ruby-harness-mcp",
        "cwd": "/path/to/my-ruby-project"
      }
    }
  }
}
```

For ZCode, the same server is registered per-workspace in
`<project>/.zcode/config.json`:

```json
{
  "mcp": {
    "servers": {
      "ask-ruby-harness-mcp": {
        "type": "stdio",
        "command": "ask-ruby-harness-mcp",
        "cwd": "/path/to/my-ruby-project"
      }
    }
  }
}
```

## Monorepos

Point the server at the monorepo root — `run_tests` with a `file:` inside a
subproject (a directory with its own Gemfile/Rakefile) runs that project's
suite:

```json
{
  "mcp": {
    "servers": {
      "ask-ruby-harness-mcp": {
        "type": "stdio",
        "command": "ask-ruby-harness-mcp",
        "cwd": "/path/to/monorepo"
      }
    }
  }
}
```

## Rails?

For Rails apps, use the Rails edition: [Agent Integration (MCP)](/ask-docs/rails/mcp)
covers `ask-rails-harness-mcp`, which boots your app and adds
`RouteInspector` (plus the engine's other Rails-native tooling).
