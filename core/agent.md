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

## Middleware (LLM Call Pipeline)

Middleware wraps every `provider.chat(...)` call with cross-cutting behavior — retry, logging, default params, and more. Configure globally; applies to all `Chat` and `Session` instances automatically.

```ruby
Ask::Agent.configure do |c|
  c.middleware.use :retry_on_failure, max_retries: 5
  c.middleware.use :log_calls, logger: Rails.logger
  c.middleware.use :default_settings, temperature: 0.7
end
```

### Built-in Middleware

| Middleware | Key | What it does |
|---|---|---|
| **RetryOnFailure** | `:retry_on_failure` | Retries on `RateLimitError`, `ServerError`, `ServiceUnavailable` with exponential backoff + jitter. Does not retry on `Unauthorized`, `ModelNotFound`, or `ConfigurationError`. Respects `retry_after` from provider errors. |
| **LogCalls** | `:log_calls` | Logs every LLM call: model, tool count, message count, duration, token usage. Custom logger support. |
| **DefaultSettings** | `:default_settings` | Injects `temperature`, `max_tokens`, `top_p`, etc. into every provider call. User-supplied values take precedence. |

### Custom Middleware

```ruby
class MyMiddleware < Ask::Agent::Middleware::Base
  def around_request(provider, request)
    Rails.logger.info "Calling #{request[:model]} with #{request[:messages].length} messages"
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = yield
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    Rails.logger.info "Completed in #{elapsed.round(3)}s"
    result
  end
end

Ask::Agent.configure { |c| c.middleware.use MyMiddleware }
```

## Stream Transforms

Stream transforms process each raw `Ask::Chunk` through a chain before yielding `ChatChunks` to your block. Useful for extracting thinking tokens, buffering text, or parsing streaming JSON.

```ruby
Ask::Agent.configure do |c|
  c.stream_transforms.use :thinking_separator
  c.stream_transforms.use :text_buffer, min_size: 100
end
```

### Built-in Transforms

| Transform | Key | What it does |
|---|---|---|
| **ThinkingSeparator** | `:thinking_separator` | Splits chunks with both `thinking` and visible `content` into two separate chunks, so you can handle reasoning independently. |
| **TextBuffer** | `:text_buffer` | Buffers rapid text deltas until they reach `min_size` characters. Reduces UI flicker and log noise. Auto-flushes before non-content chunks and at stream end. |
| **ExtractJson** | `:extract_json` | Accumulates the response and attempts JSON parsing. Check `#extracted_json` and `#json?` after the stream completes. |

### Custom Transform

```ruby
class FilterTransform < Ask::Agent::StreamTransforms::Base
  def call(chunk, &block)
    block.call(chunk) unless chunk.content == "drop_me"
  end
end

Ask::Agent.configure { |c| c.stream_transforms.use FilterTransform }
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
