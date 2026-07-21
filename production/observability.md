---
layout: default
title: Observability & Events
parent: Production
nav_order: 1
---

# Observability & Events

Instrument your agents with event-driven observability. Track costs, monitor performance, and debug behavior — all through a simple publish/subscribe pattern.

```ruby
gem "ask-instrumentation"
```

## Events System

Every agent lifecycle event publishes structured data:

```ruby
session = Ask::Agent::Session.new(model: "gpt-4o")

session.on_event do |event|
  case event
  when Ask::Agent::Events::TextDelta
    print event.content  # Stream response to user
  when Ask::Agent::Events::ToolExecutionStart
    puts "\n[Running #{event.name}...]"
  when Ask::Agent::Events::ToolExecutionComplete
    puts "\n[#{event.name} finished in #{event.duration_ms}ms]"
  when Ask::Agent::Events::LlmCallStart
    puts "[LLM call starting — model: #{event.model}]"
  when Ask::Agent::Events::LlmCallComplete
    puts "[LLM call done — #{event.input_tokens} in, #{event.output_tokens} out]"
  end
end
```

## Available Events

| Event | Fired When | Data |
|---|---|---|
| `TextDelta` | A chunk of text is streamed | `content` |
| `ToolExecutionStart` | A tool begins executing | `name`, `arguments` |
| `ToolExecutionComplete` | A tool finishes | `name`, `duration_ms`, `result` |
| `LlmCallStart` | An LLM request begins | `model`, `messages` |
| `LlmCallComplete` | An LLM request ends | `model`, `input_tokens`, `output_tokens`, `cost` |
| `TurnComplete` | A full agent turn finishes | `turn_number`, `tool_calls_count` |
| `SessionComplete` | The session ends | `turns`, `total_cost`, `duration_ms` |
| `Error` | An error occurs | `error`, `context` |

## Global Subscriptions

Subscribe to events across all sessions:

```ruby
Ask::Agent.on_event do |event|
  case event
  when Ask::Agent::Events::LlmCallComplete
    TrackCost.call(event.model, event.input_tokens, event.output_tokens)
  when Ask::Agent::Events::Error
    ErrorTracker.notify(event.error, context: event.context)
  end
end
```

## Cost Tracking

```ruby
Ask::Agent.configure do |c|
  c.track_cost = true
end

# Per-session cost
session.run("Analyze this data")
puts "Session cost: $#{session.total_cost}"

# Accumulated across all sessions
report = Ask::Agent.cost_report
# => { total_cost: 1.23, total_calls: 47, by_model: { "gpt-4o" => 0.89 } }
```

Cost tracking uses built-in pricing estimates for common models. Extend with custom pricing:

```ruby
Ask::Agent.configure do |c|
  c.pricing = {
    "gpt-4o" => { input: 0.0000025, output: 0.00001 },  # per token
    "claude-sonnet-4" => { input: 0.000003, output: 0.000015 }
  }
end
```

## Usage Analytics

```ruby
# Total usage across all sessions
Ask::Agent.usage
# => { total_tokens: 150000, total_cost: 2.50,
#      total_turns: 320, total_tool_calls: 480 }

# Usage by model
Ask::Agent.usage_by_model
# => { "gpt-4o" => { tokens: 100000, cost: 1.50 },
#      "claude-sonnet-4" => { tokens: 50000, cost: 1.00 } }
```

## Logging Setup

```ruby
Ask::Agent.configure do |c|
  c.log_level = :info  # :debug, :info, :warn, :error
  c.log_to = "log/ask-agent.log"
end
```

The log captures tool calls, LLM requests, errors, and turn completions in a structured format.

## Next Steps

- [Set up the monitoring dashboard](/ask-docs/production/monitoring)
- [Configure OpenTelemetry tracing](/ask-docs/production/opentelemetry)
- [Evaluate LLM outputs](/ask-docs/production/evaluation)
