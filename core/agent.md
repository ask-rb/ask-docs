---
layout: default
title: The Agent Loop
parent: Core Components
nav_order: 4
---


# ask-agent

Agent runtime for the ask-rb ecosystem. The core agent loop: think → call tools → execute → feed back → repeat.

**Use ask-agent when** you want to add AI capabilities to your app for your users — chatbots, automated workflows, coding assistants. Bring your own tools, persistence, and UI. Works in any Ruby app.

**Use ask-rails when** you want to give AI agents access to your Rails app — internal admin tools, ops dashboards, dev assistants. Ships with Rails-aware tools (database, filesystem, logs) and an admin chat UI at `/ask`. Rails 7.1+ only.

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

## Prompt Caching

Prompt caching saves up to 90% on input token costs for repeated conversation prefixes. It works directly through provider-native caching APIs — no proxy server needed.

**Enabled by default.** All sessions automatically send cache-control hints to supporting providers:

- **Anthropic** — Caches system prompt and last user message context. Response metadata includes `cache_creation_input_tokens` and `cache_read_input_tokens`.
- **OpenAI** — Automatic for prompts exceeding ~1024 tokens. Response metadata includes `cached_tokens`.

Providers that don't support caching (Google, Mistral, Ollama, etc.) safely ignore the parameter.

```ruby
# Disable if needed
Ask::Agent.configure do |c|
  c.prompt_caching = false
end
```

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

## Provider-Executed Tools

Some LLM providers offer built-in tools that run on their infrastructure — web search, file search, code execution. These tools don't need local execution; the provider handles them and returns results directly in the response.

Pass `Ask::ProviderTool` objects alongside regular tools in the `Session` constructor:

```ruby
session = Ask::Agent::Session.new(
  model: "gpt-4o",
  tools: [
    Bash, Read,
    Ask::ProviderTool.web_search(search_context_size: "high"),
    Ask::ProviderTool.file_search(vector_store_ids: ["vs_abc"])
  ]
)

session.run("Search for recent security advisories and check our config")
```

The agent loop automatically detects provider-executed results and adds them to the conversation without attempting local execution. Regular user-defined tools continue to run locally as before.

Available provider tools:

| Factory method | Provider | What it does |
|---|---|---|
| `Ask::ProviderTool.web_search` | OpenAI | Search the internet for current information |
| `Ask::ProviderTool.file_search` | OpenAI | Search through uploaded files in a vector store |
| `Ask::ProviderTool.code_interpreter` | OpenAI | Execute Python code in a sandboxed environment |

Custom provider tools can be created directly:

```ruby
Ask::ProviderTool.new(
  id: "openai.web_search",
  name: "web_search",
  args: { search_context_size: "high" }
)
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

## Scheduler (Recurring Agent Runs)

Schedule agents to run on cron schedules or recurring intervals. Tasks run in background threads managed by `rufus-scheduler`.

```ruby
Ask::Agent.configure do |c|
  c.scheduler.every "5 minutes", name: "health-check" do
    Ask::Agent::Session.new(model: "gpt-4o").run("Check server health")
  end

  c.scheduler.cron "0 9 * * 1-5", name: "morning-report" do
    session = Ask::Agent::Session.new(model: "gpt-4o")
    session.run("Generate daily report and send to team")
  end
end

# Start the scheduler (background thread)
Ask::Agent::Scheduler.start

# Manage at runtime
Ask::Agent::Scheduler.running?          # => true
Ask::Agent::Scheduler.jobs              # list of scheduled jobs
Ask::Agent::Scheduler.job_by_name("health-check")

# Graceful shutdown
Ask::Agent::Scheduler.stop
```

Task names are optional but recommended — they let you find and manage jobs at runtime.

## Agent Definitions (Convention-Based)

Define reusable agents in `agents/<name>/agent.rb` or `app/agents/<name>/agent.rb`. The directory name becomes the agent name. Instructions auto-load from a sibling `instructions.md`.

```
agents/
├── health_check/
│   ├── agent.rb           → Definition subclass
│   └── instructions.md    → auto-loaded system prompt
├── daily_report/
│   ├── agent.rb
│   └── instructions.md
└── shared/
    └── tools/             → shared across all agents
```

```ruby
# agents/health_check/agent.rb
class HealthCheckAgent < Ask::Agent::Definition
  model "gpt-4o"
  tools :bash, :read, :grep
  schedule "every 5 minutes"
end
```

Create sessions from definitions:

```ruby
agent = Ask::Agent.new("health_check")
agent.run("Check server health")

# List all discovered definitions
Ask::Agent.definitions.each do |name, (klass, dir)|
  puts "#{name}: #{klass.model}"
end
```

### CLI

The `askr` CLI is installed with the gem:

```bash
askr list                    # List all agents
askr run health_check        # Run an agent
askr run health_check "..."  # Run with a prompt
askr schedule                # Start the scheduler
askr new deploy_bot          # Scaffold a new agent
```

## Skills

Skills are markdown files with step-by-step methodology that agents can load on demand. They follow the `SKILL.md` convention (markdown with YAML frontmatter containing `name` and `description`).

### Where Skills Live

Skills are discovered from these locations (highest priority first):

| Location | Scope | Description |
|---|---|---|
| `agents/<name>/skills/` | Per-agent | Skills only available to one agent |
| `agents/shared/skills/` | Project-wide | Shared across all agents |
| `app/agents/shared/skills/` | Rails project | Rails variant of shared skills |
| `.agents/skills/` | Legacy | Backward compatibility path |
| `~/.config/ask/skills/` | User | Personal skills across projects |
| Installed gems | Global | Skills shipped with ask-* gems |
| Built-in | Built-in | `skill.design`, `skill.compose` |

```
agents/
├── health_check/
│   ├── agent.rb
│   ├── instructions.md
│   └── skills/
│       └── nginx_debug/SKILL.md    ← only for health_check
├── daily_report/
│   └── agent.rb
└── shared/
    ├── tools/
    └── skills/
        └── rails_debug/SKILL.md    ← for all agents
```

Skills follow a progressive disclosure pattern: **names and descriptions** are listed in the system prompt so the model knows they exist, and the **full instructions** are loaded only when the model calls the `load_skill` tool or the host calls `session.skill(name)`.

## Configuration

	```ruby
	Ask::Agent.configure do |c|
	  c.default_model = "claude-sonnet-4"
	  c.default_max_turns = 50
	  c.parallel_tool_execution = true
	  c.prompt_caching = false    # disable provider-native prompt caching
	  c.middleware.use :log_calls
	  c.stream_transforms.use :thinking_separator
	end
	```
