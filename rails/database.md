---
layout: default
title: Database Tools
parent: Rails Integration
nav_order: 2
---

# Database Tools

Seven built-in tools that give your agent deep access to your Rails application.

## Quick Start

```ruby
session = Ask::Rails.agent_session

# The agent can answer questions about your data
response = session.run("How many users signed up this week?")
```

Each tool is also usable independently:

```ruby
Ask::Rails::Tools::QueryDatabase.new.call(sql: "SELECT * FROM users")
Ask::Rails::Tools::ReadModel.new.call(name: "User")
Ask::Rails::Tools::ReadLog.new.call(lines: 50, level: "ERROR")
```

## QueryDatabase

Run read-only SQL against your application database.

```ruby
tool = Ask::Rails::Tools::QueryDatabase.new
tool.call(sql: "SELECT * FROM users", limit: 10)
# => { columns: ["id", "email", ...], rows: [...], count: 10, truncated: false }
```

**Features:**
- Auto-appends `LIMIT 50` if no limit clause is present
- **Production guard** — only `SELECT` queries allowed in production
- Binary columns replaced with `[BINARY DATA]`
- Returns structured data with column names and rows

## ReadModel

Introspect an ActiveRecord model — columns, associations, validators, and scopes.

```ruby
tool = Ask::Rails::Tools::ReadModel.new
tool.call(name: "User")
# => { name: "User", table_name: "users", primary_key: "id",
#      columns: [...], associations: {...}, validators: [...], scopes: [...] }
```

**Detail filtering:**

| Detail value | Returns |
|---|---|
| `"all"` (default) | Full introspection |
| `"columns"` | Column info only (name, type, null, default, primary_key) |
| `"associations"` | has_many, belongs_to, has_one, HABTM |
| `"validations"` | Validators with kind and options |
| `"scopes"` | Defined scope method names |

## ReadLog

Read application log files, starting from the most recent entries.

```ruby
tool = Ask::Rails::Tools::ReadLog.new
tool.call(lines: 50, level: "ERROR", search: "timeout")
# => { lines: [...], total_lines: 1203, matched_lines: 5, path: "log/production.log" }
```

**Features:**
- **Level filtering** — `ERROR`, `WARN`, `INFO`, `DEBUG`
- **Search filtering** — case-insensitive substring match
- **Rotated archives** — automatically reads `.log.1`, `.log.2.gz`, etc.
- **Max lines** — capped at 500 lines per call

## ReadRoutes

Read the complete route table.

```ruby
tool = Ask::Rails::Tools::ReadRoutes.new
tool.call
```

Returns all routes parsed from `config/routes.rb`.

## RunCommand

Run a shell command in the Rails application root directory.

```ruby
tool = Ask::Rails::Tools::RunCommand.new
tool.call(command: "rails routes --grep user")
```

## SearchCodebase

Full-text code search using grep.

```ruby
tool = Ask::Rails::Tools::SearchCodebase.new
tool.call(pattern: "class User", path: "app/models")
```

## ReadFile

Read any file from the Rails application.

```ruby
tool = Ask::Rails::Tools::ReadFile.new
tool.call(path: "app/models/user.rb")
# => { path: "app/models/user.rb", content: "...", size: 1234 }
```

Paths are relative to `Rails.root`.

## What the Agent Can Do With These

With the Rails toolset, an agent can:

- **Debug errors** — ReadLog for errors → ReadModel on relevant models → QueryDatabase for data state → SearchCodebase for related code
- **Explore unfamiliar code** — ReadRoutes → ReadModel → SearchCodebase → ReadFile
- **Answer business questions** — QueryDatabase with aggregations
- **Audit security** — SearchCodebase for patterns, ReadModel for validations

## Next Steps

- [Configure session persistence](/rails/persistence)
- [Set up error monitoring](/rails/errors)
- [Build a custom tool](/extending/custom-tools)
