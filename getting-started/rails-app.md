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
rails generate ask:agent support_bot          # app/agents/support_bot/{agent.rb,instructions.md,tools/}
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

Agents follow the ask-agent directory convention — one directory per
agent under `app/agents/`:

```
app/agents/support_bot/
├── agent.rb           # module SupportBot; class Agent < ApplicationAgent
├── instructions.md    # auto-loaded as the system prompt
└── tools/             # per-agent tools (referenced with `tools :name`)
```

```ruby
# app/agents/support_bot/agent.rb
module SupportBot
  class Agent < ApplicationAgent
    model "gpt-4o"
    # tools :search_knowledge_base
  end
end
```

`ApplicationAgent` inherits from `Ask::Agent::Definition`, which gives you:

- `model` — the LLM to use (any model from `ask-llm-providers`)
- `provider` — optional provider override when the model name doesn't
  uniquely identify one
- `max_turns` — maximum agent loop turns (default 25)
- `tools` — declare tools the agent can use (plural)

The directory name is the agent name. A sibling `instructions.md` is
auto-loaded as the system prompt:

```markdown
# app/agents/support_bot/instructions.md

You are a helpful support agent who answers questions about our products.
```

Add per-agent tools in `app/agents/support_bot/tools/`:

```ruby
# app/agents/support_bot/tools/search_knowledge_base.rb
class SearchKnowledgeBaseTool < Ask::Tool
  description "Search the knowledge base for relevant information"

  def execute(query:)
    # ...
  end
end
```

Tools shared across all agents go in `app/agents/shared/tools/`.

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
result = OrderFulfillment::Workflow.call({ order: order })
result.payment
```

Every step is checkpointed to the `ask_state` table, so a crashed workflow resumes from the last completed step — not the start.

## 6. Add tools that know your app

The real power comes from writing tools that interact with your app's models and services:

```ruby
# app/agents/support_bot/tools/search_products.rb
class SearchProductsTool < Ask::Tool
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
# app/agents/support_bot/agent.rb
module SupportBot
  class Agent < ApplicationAgent
    model "gpt-4o"
    tools :search_products
  end
end
```

## 7. Use streaming for a better UX

`Ask::Agent::Streaming` turns an agent run into Server-Sent Events. It works
in any Rack app, or with `ActionController::Live::SSE` in Rails:

```ruby
# app/controllers/chats_controller.rb
def create
  session = Ask::Agent.new("support_bot")
  response.headers["Content-Type"] = "text/event-stream"

  sse = ActionController::Live::SSE.new(response.stream)
  Ask::Agent::Streaming.run(session, params[:message]) do |type, data|
    sse.write(data, event: type)
  end
ensure
  sse&.close
end
```

Events arrive as SSE messages with types like `delta` (text chunks),
`thinking`, `tool_start`, `tool_end`, and `done`. The browser can render
these as they arrive — no polling.

For a complete Rails streaming setup, see `Ask::Agent::Streaming` in the [API reference](/ask-docs/reference/api#ask-agent).

## What's next?

- [Define custom tools](/ask-docs/extending/custom-tools)
- [Learn the core concepts](/ask-docs/getting-started/concepts)
- [Build workflows & graphs](/ask-docs/core/graph) — conditions, parallel steps, approval, timeouts
- [Use the admin copilot](/ask-docs/rails/setup) for internal debugging and ops
- [Browse the API reference](/ask-docs/reference/api)
