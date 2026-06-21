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
| `config/initializers/ask.rb` | Provider and agent configuration |
| `db/migrate/*_create_ask_sessions.rb` | Session persistence table |
| `app/tools/` | Directory for custom tools (empty) |

## Configuration

```ruby
# config/initializers/ask.rb
Ask::Rails.configure do |c|
  c.default_model = "gpt-4o"
  c.default_max_turns = 50
  c.parallel_tool_execution = true
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
Ask::Rails.configure do |c|
  # Use Anthropic instead of OpenAI
  c.default_model = "claude-sonnet-4"
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

- [Use the database tools](/rails/database)
- [Configure session persistence](/rails/persistence)
- [Set up error monitoring](/rails/errors)
