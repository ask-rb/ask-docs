---
layout: default
title: Custom Agents
parent: Extending
nav_order: 3
---

# Custom Agents

Extend `Ask::Agent::Session` with custom hooks, events, compaction strategies, and persistence backends.

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
