---
layout: default
title: ask-rails
nav_order: 4
---

# ask-rails

Rails integration for the ask-rb ecosystem. The only gem a Rails app needs to join the ask-rb stack.

## Installation

```ruby
gem "ask-rails"
rails generate ask_rails:install
```

## Components

- **Railtie** — Configures RubyLLM, discovers tools and service gems on boot
- **Persistence** — ActiveRecord adapter for session persistence
- **Session Factory** — `Ask::Rails.agent_session` creates a pre-configured agent
- **Service Discovery** — Auto-discovers installed `ask-*` gems
- **Generators** — Migration + initializer + `app/tools/`
- **Rails Tools** — ReadFile, RunCommand, SearchCodebase, ReadRoutes, QueryDatabase, ReadModel, ReadLog

## Quick Start

```ruby
session = Ask::Rails.agent_session
response = session.run("What models do we have?")
```

## Tools

### ReadFile

Read a file from the Rails app. Paths are relative to `Rails.root`.

```ruby
tool = Ask::Rails::Tools::ReadFile.new
tool.call(path: "app/models/user.rb")
# => { path: "app/models/user.rb", content: "...", size: 1234 }
```

### RunCommand

Run a shell command in the Rails app root directory.

```ruby
tool = Ask::Rails::Tools::RunCommand.new
tool.call(command: "rails routes --grep user")
```

### SearchCodebase

Search the Rails codebase with grep.

```ruby
tool = Ask::Rails::Tools::SearchCodebase.new
tool.call(pattern: "class User", path: "app/models")
```

### ReadRoutes

Read the Rails routes from `config/routes.rb`.

```ruby
tool = Ask::Rails::Tools::ReadRoutes.new
tool.call
```

### QueryDatabase (v0.2.0+)

Run a read-only SQL query against the application database. Write statements (`INSERT`, `UPDATE`, `DELETE`, etc.) are rejected in all environments.

```ruby
tool = Ask::Rails::Tools::QueryDatabase.new
tool.call(sql: "SELECT * FROM users", limit: 10)
# => { columns: ["id", "email", ...], rows: [...], count: 10, truncated: false }
```

**Limits** — Auto-appends `LIMIT 50` if no limit clause present. Respects the `limit` parameter.

**Production guard** — Only `SELECT` queries are allowed in production. Non-SELECT statements raise an error.

**Binary columns** — Binary/bytea data is automatically replaced with `[BINARY DATA]`.

### ReadModel (v0.2.0+)

Introspect an ActiveRecord model — return structured data about columns, associations, validators, and scopes.

```ruby
tool = Ask::Rails::Tools::ReadModel.new
tool.call(name: "User")
# => { name: "User", table_name: "users", primary_key: "id",
#      columns: [...], associations: {...}, validators: [...], scopes: [...] }
```

**Detail filtering** — Use the `detail` parameter to scope results:
- `"all"` (default) — full introspection
- `"columns"` — column info only (name, type, null, default, primary_key)
- `"associations"` — has_many, belongs_to, has_one, HABTM
- `"validations"` — validators with kind and options
- `"scopes"` — defined scope method names

### ReadLog (v0.2.0+)

Read application log files with filtering. Reads from the end of the file (most recent entries first).

```ruby
tool = Ask::Rails::Tools::ReadLog.new
tool.call(lines: 50, level: "ERROR", search: "timeout")
# => { lines: [...], total_lines: 1203, matched_lines: 5, path: "log/production.log" }
```

**Level filtering** — `ERROR`, `WARN`, `INFO`, `DEBUG` (case-insensitive regex match)

**Search filtering** — Case-insensitive substring match

**Rotated archives** — Automatically reads rotated log files (`.log.1`, `.log.2.gz`, etc.) in chronological order, prioritizing the most recent primary file.

**Max lines** — Capped at 500 lines per call.
