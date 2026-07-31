---
layout: default
title: Add AI to Your Rails App
parent: Getting Started
nav_order: 3
---

# Add AI to Your Rails App

Use `ask-rails` when you want to **add AI capabilities to your Rails app for your users** — chatbots that answer questions about your data, agents that automate workflows, tools that let users interact with your app through natural language.

`ask-rails` is the Rails integration layer for the ask-rb ecosystem. It provides generators, file conventions, and a railtie that make `ask-agent` feel native in Rails. The actual agent runtime comes from `ask-agent` — `ask-rails` just wires it in.

Works with Rails 7.1+.

## 1. Install

Add to your Gemfile:

```ruby
gem "ask-rails"
gem "ask-graph"   # optional — add only if you use workflows
```

Run:

```bash
bundle install
rails generate ask:install
```

The generator creates:

| File | Purpose |
|---|---|
| `config/initializers/ask.rb` | Agent + workflow configuration |
| `app/agents/application_agent.rb` | Base class for your agents |
| `app/actions/application_action.rb` | Base class for your actions |
| `app/workflows/application_workflow.rb` | Base class for your workflows (only when ask-graph is installed) |
| `db/migrate/*_create_ask_state.rb` | Shared key-value table — workflow checkpoints, backed by `Ask::Rails::State` |
| `db/migrate/*_create_ask_audit_logs.rb` | Agent session audit log |

The state table works with any database adapter (PostgreSQL, MySQL, SQLite). If you don't use ask-graph, install with `rails generate ask:install --skip-graph`.

Scaffold new components as you build:

```bash
rails generate ask:agent support_bot          # app/agents/support_bot.rb
rails generate ask:action chats create        # app/actions/chats/create.rb
rails generate ask:workflow notify_customer   # app/workflows/notify_customer/ (requires ask-graph)
```

No API keys are written by the generator. Keys are resolved at runtime by `Ask::Auth` — see step 2.

## 2. Set your API key

`Ask::Auth` resolves API keys automatically from multiple sources, checked in order:

| Source | Example |
|---|---|
| Environment variable | `export OPENAI_API_KEY="sk-..."` |
| Rails credentials | `rails credentials:edit` → `ask.openai.api_key` |
| User-level config | `~/.ask/credentials.yml` |

The simplest approach for development:

```bash
export OPENAI_API_KEY="sk-your-key-here"
```

Or use Rails credentials for a more permanent setup:

```bash
rails credentials:edit
```

```yaml
ask:
  openai:
    api_key: sk-your-key-here
```

{: .note }
The provider is auto-detected from the model name. `"gpt-4o"` resolves to OpenAI, `"claude-sonnet-4"` resolves to Anthropic, and so on. No provider config needed.

## 3. Define an agent

Create an agent definition in `app/agents/`:

```ruby
# app/agents/support_bot.rb
class Agents::SupportBot < ApplicationAgent
  model "gpt-4o"
  system_prompt "You are a helpful support agent who answers questions about our products."
end
```

`ApplicationAgent` inherits from `Ask::Agent::Definition`, which gives you:

- `model` — the LLM to use (any model from `ask-llm-providers`)
- `system_prompt` — instructions for the agent
- `tool` — declare tools the agent can use

Add tools to give your agent capabilities:

```ruby
# app/agents/support_bot.rb
class Agents::SupportBot < ApplicationAgent
  model "gpt-4o"
  system_prompt "You help users with support questions."

  tool :bash
  tool :read
  tool :grep
end
```

## 4. Run your agent

```ruby
agent = Ask::Agent.new("support_bot")
response = agent.run("How do I reset my password?")
puts response
```

For one-off conversations without a definition file:

```ruby
session = Ask::Agent::Session.new(
  model: "gpt-4o",
  system_prompt: "You are a helpful assistant."
)
response = session.run("Summarize this article")
```

## 5. Define a workflow

Workflows are multi-step, crash-safe processes — order fulfillment, document pipelines, approval flows. Scaffold one:

```bash
rails generate ask:workflow order_fulfillment
```

This creates `app/workflows/order_fulfillment/workflow.rb` and a `steps/` directory:

```ruby
# app/workflows/order_fulfillment/workflow.rb
module OrderFulfillment
  class Workflow < ApplicationWorkflow
    step ValidatePayment
    step NotifyCustomer
    step ShipOrder
  end
end
```

Steps are plain Ruby classes with a `call(context)` method:

```ruby
# app/workflows/order_fulfillment/steps/validate_payment.rb
module OrderFulfillment
  class ValidatePayment
    def call(context)
      context.payment = PaymentService.charge(context.input[:order])
    end
  end
end
```

Run it:

```ruby
result = OrderFulfillment::Workflow.call(order: order)
result.payment
```

Every step is checkpointed to the `ask_state` table, so a crashed workflow resumes from the last completed step — not the start.

## 6. Add tools that know your app

The real power comes from writing tools that interact with your app's models and services:

```ruby
# app/tools/search_products.rb
class Tools::SearchProducts < Ask::Tool
  description "Search products by name or description"

  param :query, type: :string, desc: "Search term", required: true

  def execute(query:)
    products = Product.where("name ILIKE ?", "%#{query}%").limit(10)
    {
      results: products.map { |p| { id: p.id, name: p.name, price: p.price } },
      count: products.size
    }
  end
end
```

Then register it with your agent:

```ruby
class Agents::SupportBot < ApplicationAgent
  model "gpt-4o"
  system_prompt "You help users find products."

  tool :search_products
end
```

## 7. Use streaming for a better UX

Pass a block to stream responses token-by-token:

```ruby
session = Ask::Agent::Session.new(model: "gpt-4o")

session.run("Tell me about our products") do |chunk|
  if chunk.content
    # Send to browser via ActionCable, Turbo Stream, or SSE
    ActionCable.server.broadcast("chat", { content: chunk.content })
  end
end
```

For a complete Rails streaming setup, see `Ask::Agent::Streaming` in the [API reference](/ask-docs/reference/api#ask-agent).

## What's next?

- [Define custom tools](/ask-docs/extending/custom-tools)
- [Learn the core concepts](/ask-docs/getting-started/concepts)
- [Build workflows & graphs](/ask-docs/core/graph) — conditions, parallel steps, approval, timeouts
- [Use the admin copilot](/ask-docs/rails/setup) for internal debugging and ops
- [Browse the API reference](/ask-docs/reference/api)
