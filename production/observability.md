---
layout: default
title: Observability & Events
parent: Production
nav_order: 1
---

# Observability & Events

Two layers give you visibility into your agents: an in-process event stream from the agent loop, and `ActiveSupport::Notifications` events from `ask-instrumentation` that any tool can subscribe to.

```ruby
gem "ask-instrumentation"
```

## Agent events

Every session publishes lifecycle events as it runs. Subscribe with `on_event`, or filter by event class with `on`:

```ruby
session = Ask::Agent::Session.new(model: "gpt-4o")

session.on_event do |event|
  case event
  when Ask::Agent::Events::TextDelta
    print event.content                 # stream text to the user
  when Ask::Agent::Events::ThinkingDelta
    print event.content                 # reasoning tokens, if the model emits them
  when Ask::Agent::Events::ToolExecutionStart
    puts "\n[Running #{event.name}...]"
  when Ask::Agent::Events::ToolExecutionEnd
    puts "\n[#{event.name} finished in #{event.duration_ms}ms]"
  when Ask::Agent::Events::Error
    puts "Error: #{event.error}"
  end
end

session.run("What's the current date?")
```

## Available events

| Event | Fired When | Data |
|---|---|---|
| `SessionStart` | The session begins | — |
| `SessionEnd` | The session finishes | `result`, `turn_count`, `tool_calls_made`, `input_tokens`, `output_tokens`, `cost` |
| `TurnStart` / `TurnEnd` | Each agent turn | `turn_number`, `tool_results`, tokens, `cost` |
| `MessageStart` / `MessageEnd` | Each LLM call within a turn | `tool_calls` |
| `TextDelta` | A text chunk streams | `content` |
| `ThinkingDelta` | A reasoning chunk streams | `content` |
| `ToolCallDelta` | Tool call arguments stream | `name`, `arguments`, `id` |
| `ToolExecutionStart` / `ToolExecutionUpdate` / `ToolExecutionEnd` | A tool runs | `name`, `id`, `arguments`, `partial_result`, `result`, `is_error`, `duration_ms` |
| `CompactionStart` / `CompactionEnd` | Context is compacted | `tokens_before`, `tokens_after`, `summary` |
| `LoopDetected` | The agent repeats itself | `tool_name`, `repeated_count` |
| `MaxTurnsExceeded` | The turn limit is hit | `max_turns` |
| `EvaluationStart` / `EvaluationDelta` / `EvaluationEnd` / `EvaluationBlocked` | The evaluator runs | `dimensions`, `decision`, `feedback`, `scores` |
| `ReflectionStart` / `ReflectionDelta` / `ReflectionEnd` | The reflector runs | `reflection_number`, `decision`, `feedback` |
| `Error` | An error occurs | `error`, `recoverable` |

## Cost and token tracking

Sessions accumulate usage as they run. These are real numbers from the provider responses, not estimates:

```ruby
session.run("Write a poem")
session.total_input_tokens   # => 150
session.total_output_tokens  # => 320
session.total_cost           # => 0.0015
```

The same numbers ride on `TurnEnd` and `SessionEnd` events, so you can log or charge per turn:

```ruby
session.on(Ask::Agent::Events::TurnEnd) do |event|
  Rails.logger.info "Turn #{event.turn_number}: #{event.input_tokens} in / #{event.output_tokens} out / $#{event.cost}"
end
```

## Instrumentation events

`ask-instrumentation` wraps `ActiveSupport::Notifications` and emits one event per LLM operation, named `{operation}.ask`:

| Event | Fired When |
|---|---|
| `chat.ask` | A chat completion finishes |
| `chat.stream.ask` | A streaming chat completes |
| `tool.ask` | A tool executes |
| `tool_call.ask` / `tool_result.ask` | Tool call and result round-trip |
| `embedding.ask` | Embeddings are generated |
| `image.ask` | An image is generated |

Subscribe from anywhere — a Rails initializer, a background job, a plain Ruby script:

```ruby
Ask::Instrumentation.subscribe("chat.ask") do |event|
  Rails.logger.info "LLM call: #{event.payload[:provider]} #{event.payload[:model]} " \
                    "#{event.duration}ms cost=$#{event.payload[:cost]}"
end
```

Attach metadata that flows through every event in a block:

```ruby
Ask::Instrumentation.with_metadata(user_id: current_user.id, session_id: session.id) do
  response = session.run("Summarize this article")
end
```

Instrument your own code the same way:

```ruby
Ask::Instrumentation.instrument("chat.ask", provider: "openai", model: "gpt-4o") do
  provider.chat(messages, model: "gpt-4o")
end
```

The `ask-monitoring` Rails engine subscribes to these events for its dashboard, and `ask-opentelemetry` turns them into spans. Both work with any provider.

## Telemetry

The agent ships a file-backed telemetry log for error tracking. It's on by default; configure the directory through the session:

```ruby
telemetry = Ask::Agent::Telemetry.new(dir: "log/ask/")
session = Ask::Agent::Session.new(model: "gpt-4o", telemetry: telemetry)
```

Every error and notable lifecycle event is appended as JSON lines. The `MetaAgent` component reads this same log to propose improvements (see [The Agent Loop](/ask-docs/core/agent)).

## Next Steps

- [Set up the monitoring dashboard](/ask-docs/production/monitoring)
- [Configure OpenTelemetry tracing](/ask-docs/production/opentelemetry)
- [Evaluate LLM outputs](/ask-docs/production/evaluation)
