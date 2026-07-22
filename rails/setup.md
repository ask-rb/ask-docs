---
layout: default
title: Setup & Generators
parent: Rails Integration
nav_order: 1
---

# Setup & Generators

Add AI capabilities to your Rails application.

## Installation

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

| File | Purpose |
|---|---|
| `config/initializers/ask_rails.rb` | Provider and agent configuration |
| `db/migrate/*_create_ask_sessions.rb` | Session persistence table |
| `db/migrate/*_create_ask_audit_logs.rb` | Audit log table (tool call recording) |
| `app/tools/` | Directory for custom tools (with `.keep`) |

## Configuration

```ruby
# config/initializers/ask_rails.rb
Ask::Rails.configure do |config|
  config.default_model = ENV.fetch("ASK_DEFAULT_MODEL", "gpt-4o")
  config.max_turns = ENV.fetch("ASK_MAX_TURNS", 25).to_i
end
```

### Available options

| Option | Default | Description |
|---|---|---|
| `default_model` | `"gpt-4o"` (or `ASK_DEFAULT_MODEL` env) | LLM model for agent sessions |
| `max_turns` | `25` (or `ASK_MAX_TURNS` env) | Max think-call-execute cycles per session |
| `tool_concurrency` | `5` | Number of tools the agent can run in parallel |
| `system_prompt` | `nil` (built-in default) | Custom system prompt for the agent |
| `persistence_adapter` | `nil` (in-memory) | A `Persistence` instance for saving sessions |
| `current_user` | `nil` | A proc returning a hash of user context (id, email, etc.) attached to every audit log entry |

### Per-Environment Permissions

Control access modes and command allowlists per Rails environment:

```ruby
Ask::Rails.configure do |config|
  # Production is read-only with strict command restrictions
  config.environment :production do |env|
    env.mode = :read_only
    env.allowed_commands = [/^rails routes/, /^rails log/]
    env.denied_commands = [/rm/, /dropdb/, /curl/]
  end

  # Staging asks before changes
  config.environment :staging do |env|
    env.mode = :ask_before_changes
    env.allowed_commands = [/^rails /, /^git status/]
  end

  # Development stays unrestricted (default)
  config.environment :development do |env|
    env.mode = :full_access
  end
end
```

**Available modes:**

| Mode | Effect |
|---|---|
| `:full_access` | All tools allowed, no approval needed |
| `:read_only` | Write/edit/bash/destroy tools blocked |
| `:ask_before_changes` | Write/edit/bash/destroy require approval |

When a mode is set, `agent_session` automatically creates a `Permissions` extension
that enforces the mode at the agent loop level. The command allowlist rules apply
additionally to the `RunCommand` tool.

If no environment config matches `Rails.env`, the global `allowed_commands` and
`denied_commands` are used as fallback.

### Audit Log

Every tool call is automatically recorded in the `ask_audit_logs` table with:
- **Intent** — which tool was called and with what params (sensitive keys like `password`, `token`, `api_key` are redacted)
- **Outcome** — success/error/rejected status and duration
- **User context** — who initiated the call (if `current_user` is configured)

The audit log is append-only and never stores full result data — only metadata (row counts, exit statuses, file sizes).

Subscribe to audit events in your app:

```ruby
ActiveSupport::Notifications.subscribe("audit_log.ask_rails") do |event|
  if event.payload[:tool_name] == "RunCommand" && event.payload[:status] == "error"
    SlackNotifier.notify("Agent command failed: #{event.payload[:error_message]}")
  end
end
```

### Provider configuration

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

### Customizing providers

```ruby
Ask::Rails.configure do |config|
  config.default_model = "claude-sonnet-4"
end
```

## Quick Start

```ruby
session = Ask::Rails.agent_session
response = session.run("What models do we have?")
```

The session comes pre-configured with the default model and all Rails-aware tools.

## Components

When you install ask-rails, these components are activated:

| Component | Purpose |
|---|---|
| **Railtie** | Configures providers, discovers tools and service gems on boot |
| **Session Factory** | `Ask::Rails.agent_session` creates a pre-configured agent session |
| **Service Discovery** | Auto-discovers installed `ask-*` service gems |
| **Rails Tools** | Database, filesystem, and code navigation tools |
| **Persistence** | ActiveRecord adapter for session save/load/resume |
| **Generators** | Migration, initializer, and tool scaffolding |

## Service Discovery

ask-rails automatically discovers installed service gems. If you add `ask-github` to your Gemfile, the agent knows how to interact with GitHub without additional configuration.

## Next Steps

- [Use the database tools](/ask-docs/rails/database)
- [Configure session persistence](/ask-docs/rails/persistence)
- [Set up error monitoring](/ask-docs/rails/errors)
