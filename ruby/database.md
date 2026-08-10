---
layout: default
title: Database Tools
parent: Ruby Harness
nav_order: 2
---

# Database Tools

Three tools give your agent access to the project's data layer in any Ruby
project: `QueryDatabase`, `ReadModel`, and `SchemaGraph`. They work with
ActiveRecord standalone — no Rails needed.

## Connecting

The harness connects lazily: **nothing connects at boot**, and if no
database is configured, the tools return a clear
"Database not connected. Set ASK_DATABASE_URL or provide a config/database.yml"
failure without touching the database at all.

Connection sources, in order:

1. **`ASK_DATABASE_URL`** env var
2. **`config/database.yml`** at the project root (the section matching the
   current environment, falling back to `development`)

```yaml
# config/database.yml
development:
  adapter: postgresql
  database: my_project_development
  host: localhost
  username: postgres
  pool: 2
```

Rails-style multi-database configs work too — the `primary` section is used
when present. Relative sqlite `database:` paths resolve against the project
root (like Rails does), not the harness's cwd.

### Connection footprint

The harness opens **one ActiveRecord pool** on `ActiveRecord::Base`, sized by
the config's `pool:` (AR's default is 5). Connections open lazily — one per
concurrent tool call, checked back in afterward — so an idle harness sits on
exactly the connections it has used. No database configured means **no pool
at all**.

## QueryDatabase

Run read-only SQL against the project database.

```ruby
tool = Ask::Ruby::Harness::Tools::QueryDatabase.new
tool.call(sql: "SELECT * FROM users", limit: 10)
```

Returns columns and rows — for example `{ columns: ["id", "email", ...], rows: [...], count: 10, truncated: false }`.

**Features:**
- Auto-appends `LIMIT 50` if no limit clause is present
- **Write guard** — `INSERT`, `UPDATE`, `DELETE`, `DROP`, `TRUNCATE`,
  `ALTER`, `CREATE`, `GRANT`, and `REVOKE` are rejected in all environments
- **Production guard** — only `SELECT` queries allowed in production
  (detected from `RAILS_ENV`/`RACK_ENV`/`APP_ENV`)
- Binary columns replaced with `[BINARY DATA]`

### Multi-database apps

Multi-database projects (Rails 6+ `database.yml` with named sections like
`primary`, `queue`, `cache`) can target any database with the `database:`
param — a config key or a full connection URL:

```ruby
tool.call(sql: "SELECT * FROM solid_queue_jobs", database: "queue")
tool.call(sql: "SELECT count(*) FROM users", database: "cache")
tool.call(sql: "SELECT 1", database: "postgres://user:pass@localhost:5432/other_db")
```

Named keys resolve first through the host app's own configurations registry
(so Rails apps get credential-resolved configs), then from
`config/database.yml`. The result reports which database was queried
(`"database": "queue"`), and the write guards apply to every database. A
name that exists nowhere returns a clear failure. Each named database gets
its own connection pool (established lazily on first use).

## ReadModel

Introspect an ActiveRecord model — columns, associations, validators, and
scopes. Works whenever the project's models are loaded (ActiveRecord
standalone or under Rails):

```ruby
tool = Ask::Ruby::Harness::Tools::ReadModel.new
tool.call(name: "User", detail: "all")
```

Returns `{ name:, table_name:, primary_key:, columns:, associations:, validators: }`.

## SchemaGraph

Full data-layer introspection in a single call:

```ruby
tool = Ask::Ruby::Harness::Tools::SchemaGraph.new
tool.call(detail: "all")
```

Returns a summary plus models (columns, associations, validators), the
association graph (edges between models), and tables (columns, indexes).
In a Rails app it eager-loads the app's models first; in a plain Ruby
project it introspects whatever models are already loaded.

**Agents can now answer questions like:**
- "How is User connected to Order?"
- "Which tables are missing indexes?"
- "What validations exist on the Payment model?"
