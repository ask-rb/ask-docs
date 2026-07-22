---
layout: default
title: Database Tools
parent: Rails Integration
nav_order: 2
---

# Database Tools

Nine built-in tools that give your agent deep access to your Rails application.

## Quick Start

```ruby
session = Ask::Rails.agent_session

# The agent can answer questions about your data and schema
response = session.run("How many users signed up this week?")

# Or ask about the full schema graph
response = session.run("Map out all the models and their associations")
```

Each tool is also usable independently:

```ruby
Ask::Rails::Tools::SchemaGraph.new.call(detail: "all")
Ask::Rails::Tools::QueryDatabase.new.call(sql: "SELECT * FROM users")
Ask::Rails::Tools::ReadModel.new.call(name: "User")
Ask::Rails::Tools::RouteInspector.new.call(controller: "users")
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
- **Write guard** — `INSERT`, `UPDATE`, `DELETE`, `DROP`, `TRUNCATE`, `ALTER`, `CREATE`, `GRANT`, and `REVOKE` are rejected in all environments
- **Production guard** — only `SELECT` queries allowed in production (non-SELECT read queries like `EXPLAIN` are also blocked)
- Binary columns replaced with `[BINARY DATA]`
- Returns an `Ask::Result` with `data` containing column names and rows

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

Returns the raw content of `config/routes.rb`. The agent receives the route DSL source, not a parsed route table.

## RunCommand

Run a shell command in the Rails application root directory.

```ruby
tool = Ask::Rails::Tools::RunCommand.new
result = tool.call(command: "rails routes --grep user")
# result is an Ask::Result with data: { output: "...", exit_status: 0 }
```

## RouteInspector

Returns the parsed Rails route table — every route with its HTTP verb, path, controller, and action.

```ruby
tool = Ask::Rails::Tools::RouteInspector.new

# All routes
tool.call  # => { routes: [...], count: 42 }

# Routes for a specific controller
tool.call(controller: "users")

# Routes matching a path pattern
tool.call(pattern: "admin")

# With internal route details
tool.call(verbose: true)
```

Unlike the old `ReadRoutes` (which returns the raw routes.rb file), `RouteInspector` returns structured data the agent can filter and reason about.

## SchemaGraph

Full application schema introspection in a single tool call. The agent gets a complete mental model of every model, table, column, association, and validation.

```ruby
tool = Ask::Rails::Tools::SchemaGraph.new

# Everything — models, associations, tables, indexes
tool.call(detail: "all")
# => { summary: { model_count: 12, ... },
#      models: [{ name: "User", table_name: "users", columns: [...], associations: {...}, validators: [...] }, ...],
#      associations: [{ from: "User", to: "Order", type: :has_many, foreign_key: "user_id" }, ...],
#      tables: { "users": { columns: [...], indexes: [...] }, ... } }

# Just models and their columns
tool.call(detail: "models")

# Just the association graph (edges between models)
tool.call(detail: "associations")

# Just tables, columns, and indexes
tool.call(detail: "tables")
```

**Agents can now answer questions like:**
- "How is User connected to Order?"
- "What models have polymorphic associations?"
- "Which tables are missing indexes?"
- "What validations exist on the Payment model?"

### Command allowlist

Control which commands the agent can run. Configure in your initializer:

```ruby
Ask::Rails.configure do |config|
  # Only allow these patterns
  config.allowed_commands = [/^rails /, /^git status/, /^bundle exec rspec/]

  # Explicitly deny these (takes precedence over allowed)
  config.denied_commands = [/rm /, /dropdb/, /rake db:/]
end
```

- `denied_commands` is checked first — any match blocks the command
- Then `allowed_commands` is checked — if set, the command must match at least one pattern
- If both are `nil` (default), all commands are allowed
- Blocked commands return an error and are recorded in the audit log

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

- [Configure session persistence](/ask-docs/rails/persistence)
- [Set up error monitoring](/ask-docs/rails/errors)
- [Build a custom tool](/ask-docs/extending/custom-tools)
