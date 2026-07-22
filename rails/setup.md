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
