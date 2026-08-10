---
layout: default
title: Setup & Configuration
parent: Ruby Harness
nav_order: 1
---

# Setup & Configuration

Set up the admin AI copilot for any Ruby project. **No Rails required.**

## Installation

Add to your Gemfile:

```ruby
gem "ask-ruby-harness"
```

Run:

```bash
bundle install
```

The gem loads in any Ruby process. The project root it serves (`app_root`)
defaults to the current working directory; `ask-rails-harness` pins it to
`Rails.root` for you.

## The tool surface

Six tools ship with the gem:

| Tool | What it does |
|---|---|
| `QueryDatabase` | Read-only SQL (non-SELECT rejected everywhere; SELECT-only in production) |
| `ReadModel` | Inspect an ActiveRecord model's columns, associations, validations |
| `ReadLog` | Read log files with level/search filtering and rotation support |
| `RunCommand` | Run shell commands in the project root, gated by permission rules |
| `SchemaGraph` | Full schema introspection: models, tables, columns, associations |
| `RunTests` | Structured test results with failure reruns (rails test / rspec / rake test) |

Generic file and search capabilities (read, grep, edit) are provided by the
agent's native tools — the harness focuses on what only an app-aware layer
can give an agent.

## Configuration

```ruby
Ask::Ruby::Harness.configure do |config|
  config.default_model = ENV.fetch("ASK_DEFAULT_MODEL", "deepseek-v4-flash")
  config.max_turns = ENV.fetch("ASK_MAX_TURNS", 25).to_i
end
```

### Environment permissions

Per-environment rules for agent tool access:

```ruby
Ask::Ruby::Harness.configure do |config|
  config.environment :production do |env|
    env.mode = :read_only
    env.allowed_commands = [/^bundle /]
    env.denied_commands = [/rm/, /dropdb/]
  end

  config.environment :development do |env|
    env.mode = :full_access
  end
end
```

The environment is detected from `RAILS_ENV`, `RACK_ENV`, or `APP_ENV`
(development by default). `denied_commands` takes precedence over
`allowed_commands`; when both are unset, all commands are allowed.

## Agent sessions

```ruby
Ask::Ruby::Harness.discover_tools!
session = Ask::Ruby::Harness.agent_session

response = session.run("How many records does the API return?")
```

### Custom tools

Drop tools in `app/tools/` at the project root — any class subclassing
`Ask::Ruby::Harness::Tool` is discovered and added to the session:

```ruby
# app/tools/deploy_status.rb
class DeployStatus < Ask::Ruby::Harness::Tool
  description "Show the current deploy status"
  def execute
    { status: `git log -1 --oneline`.strip }
  end
end
```

## Audit logging

Every tool call is recorded in the `ask_audit_logs` table (when it exists)
and broadcast as the `audit_log.ask_ruby_harness` ActiveSupport
notification. Sensitive params (passwords, tokens, keys) are redacted
before logging.
