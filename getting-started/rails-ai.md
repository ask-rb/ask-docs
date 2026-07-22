---
layout: default
title: Give Agents Access to Your Rails App
parent: Getting Started
nav_order: 2
---

# Give Agents Access to Your Rails App

Use `ask-rails` when you want an AI agent to inspect your database, read your code,
search logs, and run commands — for **internal/admin/ops/development use**.

The agent is mounted inside your Rails app and authenticated behind your existing auth.
This is **not for building customer-facing AI features** — use `ask-agent` directly for that.

Works with Rails 7.1+.

## 1. Install

Add to your Gemfile:

```ruby
gem "ask-rails"
```

Run:

```bash
bundle install
rails generate ask_rails:install
```

The generator creates:

- `config/initializers/ask_rails.rb` — provider and agent configuration
- `db/migrate/*_create_ask_sessions.rb` — session persistence migration
- `app/tools/` — directory for custom tools (with `.keep`)

Run the migration:

```bash
rails db:migrate
```

## 2. Configure a provider

Open `config/initializers/ask_rails.rb`:

```ruby
Ask::Rails.configure do |config|
  config.default_model = ENV.fetch("ASK_DEFAULT_MODEL", "gpt-4o")
  config.max_turns = ENV.fetch("ASK_MAX_TURNS", 25).to_i
end
```

Set your API key in Rails credentials:

```bash
rails credentials:edit
```

```yaml
openai:
  api_key: sk-your-key-here
```

Or use environment variables:

```bash
export OPENAI_API_KEY="sk-your-key-here"
```

### Available configuration

| Option | Default | Description |
|---|---|---|
| `default_model` | `"gpt-4o"` (or `ASK_DEFAULT_MODEL` env) | LLM model for agent sessions |
| `max_turns` | `25` (or `ASK_MAX_TURNS` env) | Max think-call-execute cycles per session |
| `tool_concurrency` | `5` | Number of tools the agent can run in parallel |
| `system_prompt` | `nil` (built-in default) | Custom system prompt for the agent |
| `persistence_adapter` | `nil` (in-memory) | A `Persistence` instance for saving sessions |

## 3. Use your agent

```ruby
# In a controller, job, or console
session = Ask::Rails.agent_session
response = session.run("What models do we have?")
puts response
```

The agent comes pre-configured with nine Rails-aware tools:

- **SchemaGraph** — full schema introspection: all models, tables, columns, associations, validations, indexes, and polymorphic relationships
- **RouteInspector** — parsed route table with verb, path, controller, and action (filterable by controller or pattern)
- **QueryDatabase** — run read-only SQL with auto-LIMIT (write statements rejected in all environments)
- **ReadModel** — inspect ActiveRecord models, columns, associations, validators, scopes
- **ReadLog** — search and filter Rails log files with rotated archive support
- **RunCommand** — execute shell commands from the app root (with configurable allowlist)
- **SearchCodebase** — full-text grep search in your codebase
- **ReadFile** — read any file relative to `Rails.root`
- **ReadRoutes** — read the raw route file (`config/routes.rb`)

## 4. Mount the admin chat UI

Add the engine mount and auth protection to `config/routes.rb`:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # ... your routes ...

  authenticate :user, ->(u) { u.admin? } do
    mount Ask::Rails::Engine, at: "/ask"
  end
end
```

Then visit `/ask` in your browser.

## 5. Use database tools

```ruby
session = Ask::Rails.agent_session

# The agent can answer questions about your data
response = session.run("How many users signed up this week?")
# => Agent runs: SELECT COUNT(*) FROM users WHERE created_at > ...

# Or introspect your schema
response = session.run("What associations does the User model have?")
# => Agent runs: ReadModel on User, returns columns, associations, validators
```

## 6. Persist sessions

Sessions run in-memory by default. To persist them across requests, configure
a persistence adapter:

```ruby
# config/initializers/ask_rails.rb
Ask::Rails.configure do |config|
  config.persistence_adapter = Ask::Rails::Persistence.new
end
```

The persistence adapter stores sessions in a single `ask_sessions` table
keyed by `session_id` with a JSONB `data` column.

## What's next?

- [Explore all Rails tools](/ask-docs/rails/database)
- [Configure error monitoring](/ask-docs/rails/errors)
- [Add custom tools](/ask-docs/extending/custom-tools)
- [Learn the core concepts](/ask-docs/getting-started/concepts)
