---
layout: default
title: Custom Agents
parent: Extending
nav_order: 3
---

# Custom Agents

## Agent Definitions (File Convention)

The easiest way to create a reusable agent is with `Ask::Agent::Definition`.
Create an `agent.rb` file in `agents/<name>/` or `app/agents/<name>/`:

```ruby
# app/agents/health_check/agent.rb
class HealthCheckAgent < Ask::Agent::Definition
  model "gpt-4o"
  tools :bash, :read, :grep
  schedule "every 5 minutes"
end
```

The directory name becomes the agent name. A sibling `instructions.md` is
auto-loaded as the system prompt:

```markdown
# app/agents/health_check/instructions.md

You are a health check agent. Check server status and report issues.
```

### DSL Options

| Method | Description | Example |
|---|---|---|
| `model` | LLM model identifier | `model "gpt-4o"` |
| `provider` | Provider override | `provider :opencode_go` |
| `max_turns` | Max conversation turns | `max_turns 30` |
| `parallel_tools` | Parallel tool execution | `parallel_tools false` |
| `tools` | Tool symbols or classes | `tools :bash, :read` |
| `schedule` | Cron/interval schedule | `schedule "every 5 minutes"` |
| `option` | Arbitrary Session option | `option :temperature, 0.7` |

### Using from Ruby

```ruby
agent = Ask::Agent.new("health_check")
agent.run("Check server health")
```

`Ask::Agent.new` discovers the definition by scanning `agents/` and
`app/agents/`, loads the instructions file, resolves tools, and creates
a configured `Session`.

### Tools in Agent Definitions

Tools can live in the agent's own `tools/` directory:

```
app/agents/health_check/
├── agent.rb
├── instructions.md
└── tools/
    └── check_disk.rb
```

Reference them by symbol in the definition:

```ruby
class HealthCheckAgent < Ask::Agent::Definition
  tools :check_disk
end
```

Tools in `app/agents/<name>/tools/` are auto-discovered by the agent system.
Tools defined in `app/tools/` (loaded by Rails' autoloader) can also be used
by referencing the tool class directly or registering with `Ask::Tools.register`.

## Extending Session

## When to Extend

| Scenario | Approach |
|---|---|
| Add behavior before/after tools | Use `Hooks` |
| Add behavior before/after LLM calls | Use `Hooks` |
| Custom event handling | Use `Events` |
| Custom context management | Custom `Compactor` |
| Custom storage | Custom persistence adapter |

## Custom Hooks

Hooks let you run code at specific points in the agent lifecycle:

```ruby
class LoggingHooks < Ask::Agent::Hooks
  def before_tool(name, args)
    Rails.logger.info("[Agent] Running #{name} with #{args}")
  end

  def after_tool(name, result, duration_ms)
    Rails.logger.info("[Agent] #{name} finished in #{duration_ms}ms: #{result.status}")
  end

  def before_llm(messages, model)
    Rails.logger.info("[Agent] LLM call to #{model} with #{messages.size} messages")
  end

  def after_llm(response, model, tokens_used)
    Rails.logger.info("[Agent] LLM response: #{tokens_used} tokens")
  end
end

session = Ask::Agent::Session.new(
  model: "gpt-4o",
  hooks: LoggingHooks.new
)
```

## Custom Events

Emit and subscribe to custom events:

```ruby
class MetricsEvent < Ask::Agent::Events::Base
  attribute :metric_name
  attribute :value
end

# Emit in a hook
class MetricsHooks < Ask::Agent::Hooks
  def after_tool(name, result, duration_ms)
    session.emit(MetricsEvent.new(
      metric_name: "tool.#{name}.duration",
      value: duration_ms
    ))
  end
end

# Subscribe
session.on_event do |event|
  case event
  when MetricsEvent
    StatsD.gauge(event.metric_name, event.value)
  end
end
```

## Custom Compaction

Manage context window proactively:

```ruby
class AggressiveCompactor < Ask::Agent::Compactor
  def compact(conversation)
    # Keep only the system prompt and the last 3 turns
    system_msg = conversation.messages.find { |m| m.role == :system }
    recent = conversation.messages.last(6) # 3 turns × 2 messages

    Ask::Conversation.new.tap do |c|
      c.system(system_msg.content) if system_msg
      recent.each { |msg| c.add(msg) }
    end
  end
end

session = Ask::Agent::Session.new(
  model: "gpt-4o",
  compactor: AggressiveCompactor.new
)
```

## Custom Persistence

Store sessions anywhere:

```ruby
class RedisPersistence
  def save(session)
    $redis.set("session:#{session.id}", session.to_json)
    $redis.expire("session:#{session.id}", 3600)
  end

  def load(session_id)
    data = $redis.get("session:#{session_id}")
    data ? Ask::Agent::Session.from_json(data) : nil
  end

  def delete(session_id)
    $redis.del("session:#{session_id}")
  end
end

session = Ask::Agent::Session.new(
  model: "gpt-4o",
  persistence: RedisPersistence.new
)
```

## Custom Agent Subclass

For the most control, subclass `Ask::Agent::Session`:

```ruby
class SupportAgent < Ask::Agent::Session
  def initialize(customer:, **options)
    @customer = customer
    super(**options)
    add_system_context(customer_info)
    register_tools(SupportTools.all)
  end

  def run(query)
    Rails.logger.info("[Support] #{@customer.email}: #{query}")
    start_time = Time.now
    response = super
    duration = Time.now - start_time
    Rails.logger.info("[Support] Resolved in #{duration}s")
    response
  end

  private

  def customer_info
    <<~PROMPT
      You are a support agent for Acme Corp.
      Customer: #{@customer.name} (#{@customer.plan} plan)
      Use the knowledge base and order system to help them.
    PROMPT
  end
end
```

## Full Example

```ruby
class AuditedAgent < Ask::Agent::Session
  def initialize(**options)
    super(**options)

    # Add auditing hook
    add_hook(AuditHook.new)

    # Track all events
    on_event { |e| audit_log(e) }
  end

  private

  def audit_log(event)
    AuditEntry.create!(
      session_id: id,
      event_type: event.class.name,
      data: event.to_h,
      timestamp: Time.current
    )
  end
end

class AuditHook < Ask::Agent::Hooks
  def after_tool(name, result, duration_ms)
    AuditEntry.create!(
      event_type: "tool_execution",
      data: { tool: name, duration: duration_ms, status: result.status }
    )
  end
end
```

## Next Steps

- [Publish a custom service gem](/ask-docs/extending/custom-services)
- [Create custom skills](/ask-docs/extending/custom-skills)
- [Build a custom tool](/ask-docs/extending/custom-tools)
