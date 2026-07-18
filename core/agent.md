---
layout: default
title: The Agent Loop
parent: Core Components
nav_order: 4
---


# ask-agent

Agent runtime for the ask-rb ecosystem. The core agent loop: think → call tools → execute → feed back → repeat.

Ported from `RubyLLM::Conductor` to `Ask::Agent` namespace.

## Installation

```ruby
gem "ask-agent"
```

## Components

| Component | Purpose |
|---|---|
| `Session` | Full agent loop — message → tool calls → results → follow-up |
| `Loop` | Turn management with loop detection and max-turn guard |
| `ToolExecutor` | Parallel/sequential tool execution with retry and abort |
| `Compactor` | Context window management (proactive + overflow) |
| `Hooks` | Before/after tool lifecycle callbacks |
| `Events` | Streaming events for monitoring |
| `Telemetry` | File-backed telemetry for error tracking |
| `Reflector` | Assistant response self-evaluation |
| `MetaAgent` | Self-improvement from telemetry analysis |

## Quick Start

```ruby
session = Ask::Agent::Session.new(
  model: "gpt-4o",
  tools: [Ask::Tools::Shell::Bash]
)

response = session.run("List the current directory")
puts response
```

If a model is registered under one provider but served by another — for example, `deepseek-v4-flash` served by `opencode_go` — pass the `provider:` override:

```ruby
session = Ask::Agent::Session.new(
  model: "deepseek-v4-flash",
  provider: :opencode_go,
  tools: [Ask::Tools::Shell::Bash]
)
```

The `provider:` parameter tells the agent which provider to use, regardless of which provider the model is registered under in the catalog.

## Cost & Token Tracking

Every session tracks cumulative token usage and cost:

```ruby
session.run("Write a poem")
session.total_input_tokens   # => 150
session.total_output_tokens  # => 320
session.total_cost           # => 0.0015
```

Turn and session events carry the same data:

```ruby
session.on(Ask::Agent::Events::TurnEnd) do |event|
  puts "Turn #{event.turn_number}: #{event.input_tokens} in / #{event.output_tokens} out / $#{event.cost}"
end

session.on(Ask::Agent::Events::SessionEnd) do |event|
  puts "Session total: #{event.input_tokens} in / #{event.output_tokens} out / $#{event.cost}"
end
```

## Instrumentation

The agent emits `ActiveSupport::Notifications` events via `ask-instrumentation`:

- `chat.ask` — on each completion (model, provider, tokens, cost)
- `chat.stream.ask` — on each streaming completion

Subscribe from anywhere in your app:

```ruby
Ask::Instrumentation.subscribe("chat.ask") do |event|
  Rails.logger.info "LLM call: #{event.payload[:model]} cost=$#{event.payload[:cost]}"
end
```

The `ask-monitoring` Rails engine hooks into these automatically for its dashboard.

## Rate-Limit Handling

When a provider returns `RateLimitError`, the agent retries up to 3 times with exponential backoff. If the provider includes a `Retry-After` header, that value is used instead. No configuration needed.

## Events

```ruby
session.on_event do |event|
  case event
  when Ask::Agent::Events::TextDelta
    print event.content
  when Ask::Agent::Events::ToolExecutionStart
    puts "Running #{event.name}..."
  end
end
```

## Extensions

- **PermissionGate** — Require approval for destructive tools
- **RateLimiter** — Prevent runaway tool calls
- **AuditLog** — Immutable, append-only tool call log

## Configuration

```ruby
Ask::Agent.configure do |c|
  c.default_model = "claude-sonnet-4"
  c.default_max_turns = 50
  c.parallel_tool_execution = true
end
```
