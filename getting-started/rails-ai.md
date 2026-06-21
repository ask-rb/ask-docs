---
layout: default
title: AI in Your Rails App
parent: Getting Started
nav_order: 2
---

# AI in Your Rails App

Add an AI agent to your Rails application with a single gem. Works with Rails 7.1+.

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

- `config/initializers/ask.rb` — provider and agent configuration
- `db/migrate/*_create_ask_sessions.rb` — session persistence migration
- `app/tools/` — directory for custom tools

Run the migration:

```bash
rails db:migrate
```

## 2. Configure a provider

Open `config/initializers/ask.rb`:

```ruby
Ask::Rails.configure do |c|
  c.default_model = "gpt-4o"
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

## 3. Use your agent

```ruby
# In a controller, job, or console
session = Ask::Rails.agent_session
response = session.run("What models do we have?")
puts response
```

The agent comes pre-configured with Rails-aware tools:

- **QueryDatabase** — run read-only SQL with auto-LIMIT and production guard
- **ReadModel** — inspect ActiveRecord models, associations, validators, scopes
- **ReadLog** — search and filter Rails log files
- **ReadRoutes** — examine the route table
- **RunCommand** — execute shell commands from the app root
- **SearchCodebase** — full-text grep search in your codebase

## 4. Try it in a controller

```ruby
# app/controllers/agents_controller.rb
class AgentsController < ApplicationController
  def ask
    session = Ask::Rails.agent_session
    @response = session.run(params[:prompt])
    render json: { response: @response }
  rescue Ask::Agent::MaxTurnsExceeded => e
    render json: { error: "Agent took too many turns" }, status: 422
  end
end
```

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

QueryDatabase is **read-only in production** — write statements are rejected.

## 6. Persist sessions

Sessions are automatically saved to the database when you provide a `user_id`:

```ruby
session = Ask::Rails.agent_session(user: current_user)
session.run("Analyze this week's errors")

# Later
session = Ask::Rails.resume(session.id)
session.run("Now tell me about last week")
```

## What's next?

- [Explore all Rails tools](/rails/database)
- [Configure error monitoring](/rails/errors)
- [Add custom tools](/extending/custom-tools)
- [Learn the core concepts](/getting-started/concepts)
