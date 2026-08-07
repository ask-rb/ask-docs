---
layout: default
title: The Agent Loop
parent: Core Components
nav_order: 4
---


# ask-agent

Agent runtime for the ask-rb ecosystem. The core agent loop: think → call tools → execute → feed back → repeat.

**Use ask-agent when** you want to add AI capabilities to your app for your users — chatbots, automated workflows, coding assistants, and more. Bring your own tools, persistence, and UI. Works in any Ruby app.

**Use ask-rails-harness when** you want to give AI agents access to your Rails app — internal admin tools, ops dashboards, dev assistants. Ships with Rails-aware tools (database, filesystem, logs) and an admin chat UI at `/ask`. Rails 7.1+ only.

**Use ask-rails when** you want to add AI capabilities to your Rails app for your users. Provides generators, file conventions, and a railtie for building agents with the ask-rb ecosystem. Rails 7.1+ only.

**Use ask-graph when** the process is deterministic — a fixed sequence of steps you can write up front, with checkpointing and crash recovery. Agents are for open-ended, model-driven work; graphs are for pipelines with a known shape. See [ask-graph vs ask-agent](/ask-docs/core/graph#ask-graph-vs-ask-agent).

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
| `Evaluator` | Independent response evaluation with structured rubric, separate model, isolated context |
| `MetaAgent` | Self-improvement from telemetry analysis |

## Quick Start

```ruby
session = Ask::Agent::Session.new(
  model: "deepseek-v4-flash",
  tools: [Ask::Tools::Bash]
)

response = session.run("Run `ruby -v` and answer with only the version string.")
puts response
```

If a model is registered under one provider but served by another — for example, `deepseek-v4-flash` served by `opencode_go` — pass the `provider:` override:

```ruby
session = Ask::Agent::Session.new(
  model: "deepseek-v4-flash",
  provider: :opencode_go,
  tools: [Ask::Tools::Bash]
)
```

The `provider:` parameter tells the agent which provider to use, regardless of which provider the model is registered under in the catalog.

## Cost & Token Tracking

Every session tracks cumulative token usage and cost:

```ruby
session.run("Write a Ruby method that computes factorials")
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

## Audit Log

{: .new }

The agent can log all lifecycle events (tool calls, errors, token usage, turns) to a configurable audit log. This is useful for debugging, compliance, and visibility into what your agents are doing.

### Configuration

```ruby
# Global — all sessions use this adapter
Ask::Agent.configure do |c|
  c.audit_log = { adapter: :active_record }
end

# Per-session override
session = Ask::Agent::Session.new(
  model: "deepseek-v4-flash",
  audit_log: { adapter: :file, path: "tmp/my_agent_audit.jsonl" }
)
```

### Built-in Adapters

| Adapter | Description |
|---|---|
| `:active_record` | Writes to an `ask_audit_logs` table. Auto-creates the table on first write. For Rails: run `rails generate ask:install` for a proper migration. |
| `:file` | Appends JSON lines to a file. Good for development. |
| Custom | Any object implementing `#write(entry)` — see `Ask::Agent::Policies::AuditLog::Adapter`. |

### Logged Events

| Event | Stored Data |
|---|---|
| `session_start` | — |
| `session_end` | turn_count, tool_calls_made, input_tokens, output_tokens, cost |
| `turn_end` | turn_number, tool_results_count, tokens, cost |
| `tool_execution_start` | name, args (sensitive fields redacted) |
| `tool_execution_end` | name, id, duration_ms, is_error, result |
| `error` | message, recoverable |
| `max_turns_exceeded` | max_turns |
| `loop_detected` | tool_name, repeated_count |
| `compaction_end` | tokens_before, tokens_after |
| `evaluation_blocked` | feedback, scores |

Sensitive arguments (`password`, `token`, `api_key`, `sql`, `command`) are redacted automatically.

### Migration

If you're using Rails, generate the audit log migration:

```bash
rails generate ask:install
```

This creates `db/migrate/create_ask_audit_logs.rb` with the correct table schema.

## Evaluator

{: .new }
> New in ask-agent 0.15.0

Independent response evaluation with **generator/evaluator separation**. The evaluator uses a separate model (different from the session's model) and an isolated context to judge the agent's output — preventing the anti-pattern of a model grading its own work.

This is different from `Reflector` (which has the same model evaluate its own output). The `Evaluator` uses an independent model and a structured rubric, so the agent that writes the code is never the one that checks it.

### Quick Start

```ruby
session = Ask::Agent::Session.new(
  model: "deepseek-v4-flash",
  evaluator: { model: "claude-sonnet-4", goal: "Write an email validator" }
)
session.run("Write a Ruby method that validates email addresses")
```

### Verdicts

| Verdict | What Happens |
|---------|-------------|
| `:accept` | Output passes — falls through to the reflector for backward compatibility |
| `:revise` | Evaluator provides actionable feedback; session runs another turn with feedback injected into system context |
| `:block` | Output is fundamentally wrong — session returns a blocked message and emits `EvaluationBlocked` |

### Configuration

```ruby
# Set a global default evaluator model
Ask::Agent.configure do |c|
  c.default_evaluator_model = "claude-sonnet-4"
end

# Then enable with the default
session = Ask::Agent::Session.new(model: "deepseek-v4-flash", evaluator: true)

# Or pass nothing (default) — no evaluation, backward compatible
session = Ask::Agent::Session.new(model: "deepseek-v4-flash")
```

### Custom Rubric

The default rubric evaluates five dimensions (correctness, completeness, verification, scope, clarity). Pass a custom rubric for domain-specific evaluation:

```ruby
evaluator = Ask::Agent::Evaluator.new(
  model: "claude-sonnet-4",
  rubric: [
    Ask::Agent::Evaluator::Dimension.new(
      name: "performance",
      description: "Is the implementation efficient?",
      weight: 2
    )
  ]
)

result = evaluator.evaluate(
  goal: "Write an email validator",
  response: agent_output
)

result.accept?  # => true
result.revise?  # => false
result.block?   # => false
result.scores   # => { performance: 2 }
result.feedback # => "" or "Add unicode character handling"
```

### Events

The evaluator emits its own events during evaluation:

```ruby
session.on_event do |event|
  case event
  when Ask::Agent::Events::EvaluationStart
    puts "Evaluating against: #{event.dimensions.join(', ')}"
  when Ask::Agent::Events::EvaluationDelta
    print event.content
  when Ask::Agent::Events::EvaluationEnd
    puts "Decision: #{event.decision}"
    puts "Scores: #{event.scores}"
  when Ask::Agent::Events::EvaluationBlocked
    puts "Blocked: #{event.feedback}"
  end
end
```

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

## Persistence (State)

By default sessions run entirely in memory. Pass a `state:` adapter to persist
conversations across restarts — every turn is saved immediately, so a crash
mid-conversation doesn't lose progress.

### Quick Start

<!-- docs-example: not-verified -->
```ruby
require "ask-agent"
require "ask-state-providers"

store = Ask::State::Providers::SQLite.new  # or Redis, Postgres, MySQL

session = Ask::Agent::Session.new(
  model: "deepseek-v4-flash",
  tools: [Ask::Tools::Bash],
  state: store
)

session.run("Investigate the error")
# Every turn is persisted automatically to the store
```

### Backends

Any `Ask::State::Adapter` works. The `ask-state-providers` gem ships four:

| Backend | Class | Best For |
|---------|-------|----------|
| **SQLite** | `Ask::State::Providers::SQLite` | CLI tools, single-user agents, local dev |
| **Redis** | `Ask::State::Providers::Redis` | Distributed multi-process deployments |
| **PostgreSQL** | `Ask::State::Providers::Postgres` | Rails apps with an existing DB pool |
| **MySQL** | `Ask::State::Providers::MySQL` | Teams already running MySQL |

```ruby
# SQLite — zero config
store = Ask::State::Providers::SQLite.new

# Redis — for distributed setups
store = Ask::State::Providers::Redis.new(url: ENV["REDIS_URL"])

# PostgreSQL — reuse your existing connection
store = Ask::State::Providers::Postgres.new(url: ENV["DATABASE_URL"])
```

### Save & Resume

```ruby
session = Ask::Agent::Session.new(model: "deepseek-v4-flash", state: store)
session.run("Analyze the logs")
session_id = session.id  # save this somewhere

# Later, in a different process or after a restart:
restored = Ask::Agent::Session.load(session_id, adapter: store)
restored.run("What else should I check?")  # picks up where it left off
```

A session is persisted after every LLM turn and all its metadata (model, tools,
turn count, token usage) is preserved across loads.

### Checkpoints: fork, rollback, resume (v0.30.0+)

With `checkpoints: true`, every turn is snapshotted as a versioned
checkpoint — and the session gains time travel:

```ruby
session = Ask::Agent::Session.new(
  model: "deepseek-v4-flash",
  tools: [Ask::Tools::Bash],
  state: store,          # any adapter — see backends above
  checkpoints: true
)

session.run("Investigate the error")
session.checkpoint_history          # => [1, 2, 3, ...] seqs, oldest first

# Rewind to before the bad turn — later checkpoints are kept, so the
# session can roll forward again
session.rollback!(turn: 1)

# Branch from a checkpoint: a new session with its own history and
# checkpoint chain; continue it with run
forked = session.fork(at_seq: 1)
forked.run("Try a different approach")
```

- **`rollback!(seq: / turn:)`** restores messages and turn count from the
  snapshot; `fork(at_seq: / at_turn:)` returns a new session (same model and
  tools) diverging from that point.
- **`load_checkpoint(seq:)`** inspects a snapshot; `Session.load` re-enables
  checkpointing automatically when the stored session has checkpoints.
- **No provider mandate** — checkpoints need only the minimal KV contract
  (`get`/`set`/`delete`), so they work with every backend above and with
  custom adapters. No `state:` means in-memory as before; add `checkpoints:
  true` on top of whatever store you already chose.
- `Events::SessionRolledBack` / `Events::SessionForked` fire on rollback and
  fork; `Session#delete` removes checkpoint keys too.

### Backward Compatibility

The old `persistence:` keyword still works but is deprecated:

```ruby
session = Ask::Agent::Session.new(model: "deepseek-v4-flash", persistence: store)
```

Prefer `state:` — it's shorter and matches the `Ask::State::Adapter` naming.

### Custom Adapter

Any object responding to `get(key)`, `set(key, value)`, and `delete(key)` works
as a state adapter. This makes it trivial to persist to any backend:

```ruby
class RedisAdapter
  def get(key)  = redis.get(key).then { |v| v ? JSON.parse(v) : nil }
  def set(key, value, ttl: nil) = redis.set(key, JSON.generate(value), ex: ttl)
  def delete(key) = redis.del(key)
end

session = Ask::Agent::Session.new(model: "deepseek-v4-flash", state: RedisAdapter.new)
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

## Sub-Agent Delegation

{: .new }
> New in ask-agent 0.19.0

Delegate sub-tasks to specialized sub-agents using `Ask::Agent::SubAgent`.
The coordinator agent sees it as a regular tool — when called, a fresh sub-agent
session runs independently with its own model, tools, and instructions.

`Ask::Agent::SubAgent` satisfies the tool duck type directly (`name`,
`description`, `params_schema`, `call`) — pass it in the tools array
just like any other tool. No wrapping or factory needed.

### From a filesystem definition

If you already have an agent defined in `agents/<name>/agent.rb`, reference
it by name:

```ruby
# agents/web_search/agent.rb defines model, tools, instructions
search = Ask::Agent::SubAgent.new("web_search")

coordinator = Ask::Agent::Session.new(
  model: "deepseek-v4-flash",
  tools: [search, Ask::Tools::Bash]
)
```

This is the same definition convention used by `Ask::Agent.new("name")`.

### Inline configuration

```ruby
search = Ask::Agent::SubAgent.new(
  name: "web_search",
  description: "Search the web for current information",
  model: "deepseek-v4-flash",                              # cheaper model for search
  tools: [Ask::Tools::WebSearch],
  system_prompt: "You are a research assistant."
)

review = Ask::Agent::SubAgent.new(
  name: "code_review",
  description: "Review code for bugs, style issues, and security problems",
  model: "claude-sonnet-4",                           # better at code review
  tools: [Ask::Tools::Read, Ask::Tools::Grep],
  system_prompt: "You are a senior code reviewer. Be thorough."
)

coordinator = Ask::Agent::Session.new(
  model: "deepseek-v4-flash",
  tools: [search, review, Ask::Tools::Bash]
)

coordinator.run("Find the latest Rails release and check our Gemfile")
```

### With a custom provider

```ruby
review = Ask::Agent::SubAgent.new(
  name: "code_review",
  model: "claude-sonnet-4",
  provider: :anthropic,
  tools: [Ask::Tools::Read, Ask::Tools::Grep],
  system_prompt: "You are a senior code reviewer."
)
```

### What happens at runtime

1. The coordinator LLM decides to call `web_search` with `task: "Latest Rails version"`
2. A fresh sub-agent session starts with `deepseek-v4-flash` + `WebSearchTool`
3. The sub-agent searches, processes results, and returns a concise answer
4. The coordinator receives this as a normal tool response and continues

### Error isolation

If a sub-agent fails (provider outage, rate limit, max turns exceeded), the error
returns as a regular tool error message. The coordinator can decide to retry,
rephrase, or skip — the main conversation isn't disrupted.

```ruby
# Multiple sub-agents, each with distinct identity
tools = [
  Ask::Agent::SubAgent.new(name: "data_analysis", model: "deepseek-v4-flash", tools: [Analyzer]),
  Ask::Agent::SubAgent.new(name: "fact_check",    model: "deepseek-v4-flash", tools: [WebSearch])
]
```

## Provider-Executed Tools

Some LLM providers offer built-in tools that run on their infrastructure — web search, file search, code execution. These tools don't need local execution; the provider handles them and returns results directly in the response.

Pass `Ask::ProviderTool` objects alongside regular tools in the `Session` constructor:

```ruby
session = Ask::Agent::Session.new(
  model: "deepseek-v4-flash",
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

## Context Compaction

{: .new }
> Model-aware reserve in ask-agent 0.25.0

Long conversations eventually outgrow the model's context window. The
`Compactor` summarizes older messages and replaces them with a structured
summary, preserving a recent tail verbatim.

### Model-aware reserve (default)

Compaction triggers when the conversation tokens exceed
`context_window - reserve`. The reserve is derived from the model's declared
`max_output_tokens` (capped at 20,000), so the agent always keeps exactly the
headroom a single turn can consume. Models without declared limits get a
static 20,000-token reserve. A safety floor clamps the reserve for
tiny-window models so compaction can fire usefully.

```ruby
# Default (reserve mode)
compactor = Ask::Agent::Compactor.new

# Legacy: compact at 80% of the window
compactor = Ask::Agent::Compactor.new(threshold: 0.8)

# Explicit headroom
compactor = Ask::Agent::Compactor.new(reserve_tokens: 5_000)
```

### Token-aware recent tail

`keep_recent_tokens:` preserves the last N tokens of conversation verbatim
(default 8,000) and summarizes only what's older — recent-context fidelity
depends on the active work, not message counts. When not configured, the
legacy fixed message-count tail (`keep_count:`, default 8) is used.

```ruby
compactor = Ask::Agent::Compactor.new(keep_recent_tokens: 12_000)
```

### Global configuration

```ruby
Ask::Agent.configure do |c|
  c.compactor_reserve_tokens = 10_000        # headroom for one turn
  c.compactor_keep_recent_tokens = 12_000    # verbatim recent tail
end
```

### Overflow recovery

When the LLM returns a context-overflow error, the session compacts
automatically and retries. A second overflow in the same session falls back
to `microcompact!`, which clears oversized tool results in place (rebuilding
messages and preserving tool-call IDs).

### Events

Compaction emits `CompactionStart` and `CompactionEnd` events:

```ruby
session.on(Ask::Agent::Events::CompactionStart) do |event|
  puts "Compacting from #{event.tokens_before} tokens"
end

session.on(Ask::Agent::Events::CompactionEnd) do |event|
  puts "Compacted #{event.tokens_before} → #{event.tokens_after} tokens"
end
```

## Tool Approval (Human-in-the-Loop)

{: .new }
> New in ask-agent 0.27.0

Give humans a review point before side-effecting tools run. A tool declared
`approval_required` (ask-tools 0.6.0) is queued instead of executed: the agent
gets a pending result and continues, and the tool runs only after a human
approves it. Built on the async-tools seam (`Ask::Result.pending` →
`register_pending_tool` → `complete_pending_tool`), so the agent never blocks
on an approval.

### Declaring a tool

```ruby
# ask-tools
class SendEmail < Ask::Tool
  approval_required true
  param :to, type: :string, desc: "Recipient", required: true
  param :body, type: :string, desc: "Body", required: true

  def execute(to:, body:)
    Ask::Result.ok(data: "Email sent to #{to}")
  end
end
```

### Enabling approval on a session

```ruby
session = Ask::Agent::Session.new(
  model: "gpt-4o",
  tools: [SendEmail],
  approval: true                       # defaults
)

# Rule-based classification + auto-approval rules:
session = Ask::Agent::Session.new(
  model: "gpt-4o",
  tools: [SendEmail, Ping],
  approval: {
    require_approval: ["destroy", /^admin_/],   # extra tools to gate
    auto_approve: { "ping" => true }            # user-enabled auto-approval
  }
)

session.run("Email bob about the launch")
```

### Permission Rules (v0.31.0+)

{: .new }
> New in ask-agent 0.31.0

Persisted `allow` / `ask` / `deny` patterns classify every tool call before
it executes or prompts — "approve once, remember the pattern":

```ruby
rules = Ask::Agent::Policies::PermissionRules.new do |r|
  r.allow :bash, /^git (pull|push|status)/   # these run without asking
  r.ask   :bash, /^rm -rf/                   # always prompt for destructive
  r.deny  :write, %r{/\.env(\.local)?$}      # never touch secrets
  r.ask   :destroy, :all
end

session = Ask::Agent::Session.new(
  model: "gpt-4o",
  tools: [Bash, Write, Destroy],
  approval: { rules: rules }
)
```

- Tool patterns: exact name (`"bash"`), `Symbol`, `Regexp`, or `:all`.
  Argument patterns: `Regexp`, substring, or omitted for any arguments
  (hashes are matched as JSON). First matching rule wins, in declaration
  order.
- Rules take precedence over tool declarations: `:deny` blocks outright,
  `:allow` proceeds without the queue (even for `approval_required` tools),
  `:ask` queues regardless of `auto_approvable`.
- **Dangerous-rule guard**: an unrestricted `:allow` on a code-executing
  tool (`bash`, `code`, `repl`, or `:all`) is downgraded to `:ask` — so
  "approve once" can't become "approve anything". Opt out explicitly with
  `PermissionRules.new(auto_allow_dangerous: true) { ... }`; `rules.dangerous_rules`
  lists what the guard caught.

### Deciding later

```ruby
session.approval_queue.pending_actions   # [{id: 1, tool_name: "send_email", ...}]
session.approval_queue.approve(1)        # executes the tool, feeds result back
session.approval_queue.reject(1)         # injects "rejected by the user"
session.approval_queue.approve_all
session.approval_queue.reject_all
```

- **Approving** executes the real tool call and the follow-up turn voices the
  outcome. **Rejecting** injects a "rejected by the user" message and the
  agent adapts. Failed applies leave the action pending for retry.
- **Auto-approval is a dual signal**: a tool marked `auto_approvable` AND a
  user rule enabling it (`auto_approve: { "tool_name" => true }`). Nothing is
  silently applied past a manual (non-auto-approvable) gate — eligible actions
  drain in id order with a single-flight guard (no double-apply).

### Standalone hook

`Ask::Agent::Policies::ApprovalPolicy` works as a plain `before_tool` hook
for full control:

```ruby
queue = Ask::Agent::ApprovalQueue.new
policy = Ask::Agent::Policies::ApprovalPolicy.new(
  queue: queue, tools: [SendEmail], require_approval: :all
)
session = Ask::Agent::Session.new(
  model: "gpt-4o",
  tools: [SendEmail],
  hooks: { before_tool: [policy.method(:before_tool_call)] }
)
```

## Tool-Call Repair (v0.29.0+)

Models occasionally emit tool calls that can't execute: unparseable JSON
arguments, or a tool name that doesn't exist. Without repair, the call fails
and the agent burns a turn seeing the error. With repair, the loop asks the
model to re-emit the malformed calls corrected — one internal LLM
round-trip — and executes the corrected versions:

```ruby
# Built-in repair prompt
session = Ask::Agent::Session.new(model: "gpt-4o", tools: tools, tool_call_repair: true)

# Custom repair function — receives (chat, calls, tools); return a hash of
# corrections keyed by the original call ids
session = Ask::Agent::Session.new(
  model: "gpt-4o", tools: tools,
  tool_call_repair: ->(chat, calls, tools) {
    { calls.keys.first => Ask::Agent::ToolCallInfo.new(
        id: calls.keys.first, name: "bash", arguments: "{}"
      ) }
  }
)
```

- Corrections keep the **original call ids**, so tool results stay consistent
  with the conversation history; the internal repair exchange is stripped
  from history.
- Calls the model cannot correct are dropped — it saw them in the repair
  prompt. Repair is best-effort: a failing round-trip drops the malformed
  calls instead of failing the turn.
- `Events::ToolCallRepaired` fires with `name`, `id`, `original_arguments`,
  and `corrected_arguments`.

## Large-Output Offloading (v0.36.0+)

{: .new }
> New in ask-agent 0.36.0

Large tool results (giant greps, diffs, stack traces) never bloat the
transcript: they are stored separately, and the conversation keeps a short
preview plus a reference the model can retrieve on demand:

```ruby
session = Ask::Agent::Session.new(
  model: "deepseek-v4-flash",
  tools: tools,
  offload_large_outputs: true        # threshold 4000 chars; or an Integer
)

# Tool returns 50KB → transcript gets:
#   "line xxxx...
#    ...(output truncated: 52400 chars — full output via output_read id: \"call_123\")"
# The model calls output_read(id: "call_123") when it actually needs the
# full output; the web UI reads the same store.
```

- **Where it lives**: `Ask::Agent::ToolOutputStore` — pure KV on the same
  `Ask::State::Adapter` as sessions, checkpoints, and memory
  (`output:<session_id>:<call_id>` + JSON index), so every backend works
  and the web UI can fetch from the store it already reads. Without a
  `state:`, an in-process store still keeps the transcript clean.
- **`output_read` is exempt** from offloading — its contract is to bring
  the full output into context when the model asks for it.
- Stored outputs are capped (`max_size:`, default 50,000 chars) and cleaned
  up by `Session#delete`.

## Steer (v0.37.0+)

{: .new }
> New in ask-agent 0.37.0

Concurrency-safe message injection from any thread — a web client, the CLI,
or another agent can redirect a running session without racing it:

```ruby
# While a turn is running:
session.steer("Wait — use the staging database instead", expected_turn_id: 3)
# => { status: :queued, turn_id: 3 }  — dispatched as the next user message
# => { status: :stale,  turn_id: 4 }  — caller's view was outdated, rejected

# When idle:
session.steer("Actually, skip the report")
# => { status: :steered, turn_id: 3 } — added to the conversation
```

- **`:stale`** — `expected_turn_id` doesn't match the current turn id: the
  caller was looking at an older state and the message is rejected (no
  lost updates from two clients steering at once).
- **`:queued`** — a turn is running; the message is held and dispatched as
  the next user message at the next turn boundary — no abort-and-retry.
- **`:steered`** — the session is idle; the message enters the conversation
  and the next `run` processes it. Queued leftovers drain at the next run
  start.
- `Session#turn_id` reports the running turn; `Session#queued_steers` the
  pending count. ask-app-server's `inject_message` uses `steer` natively.

## Artifacts (v0.38.0+)

{: .new }
> New in ask-agent 0.38.0

Tool deliverables with a web-friendly home. Any tool can attach an artifact
to its result — small text goes inline in the state store, large/binary
files are stored as external URIs:

```ruby
session = Ask::Agent::Session.new(
  model: "deepseek-v4-flash",
  tools: tools,
  artifacts: true
)

# In a tool's execute:
Ask::Result.ok(
  data: "Report generated",
  metadata: { artifact: { filename: "report.csv", mime_type: "text/csv", content: "a,b\n1,2\n" } }
)

# Large/binary deliverables reference external storage instead:
#   metadata: { artifact: { filename: "scan.pdf", mime_type: "application/pdf",
#                           uri: "s3://bucket/scan.pdf" } }

# After the run:
session.artifacts          # => [{id:, filename:, mime_type:, size:, uri:}, ...]
session.fetch_artifact(id) # => full record (content or uri)
```

- **Two kinds, one contract**: `content:` (small text — reports, CSVs,
  patches — stored in the state adapter, capped at 100KB) or `uri:`
  (large/binary — the store keeps the reference and metadata only, so the
  database never grows beyond its comfort zone).
- **Uploader hook** — `artifact_uploader: ->(content:, filename:, mime_type:) { uri }`
  lifts inline content to a URI before storage: tools return content, the
  session uploads (S3, object storage, ...), the store keeps the reference.
- `Session#delete` cleans up artifacts. Malformed artifacts are noted in
  the tool message, never a tool failure.
- **ask-app-server** exposes `session/artifacts` (list) and
  `session/artifact/get` (fetch) protocol methods.

## Todos (Task List) (v0.32.0+)

{: .new }
> New in ask-agent 0.32.0

The model maintains a live task list through a `todo_write` tool — the
externalized plan it checks against each step, and the progress surface for
humans:

```ruby
session = Ask::Agent::Session.new(model: "gpt-4o", tools: tools, todos: true)

# The model writes and updates todos as it works:
#   todo_write(action: "add", title: "Investigate the error")
#   todo_write(action: "update", id: "todo_1", status: "completed")
```

- Actions: `add` (with `title`), `update` (with `id` and `status`/`title`),
  `list`, `clear`; statuses `pending`, `in_progress`, `completed`,
  `blocked`. Every result returns the full list, so one call both mutates
  and shows state.
- `Events::TodoUpdated` fires with the full list on every change — the
  contract for live progress rendering in a UI.
- The list rides checkpoints: `rollback!` and `fork` restore it, and
  `Session.load` re-enables todos automatically.

## Plan Mode (v0.32.0+)

{: .new }
> New in ask-agent 0.32.0

A phase gate: the agent researches read-only, proposes a plan, and only
executes after a human approves it — one decision instead of approving every
tool call:

```ruby
session = Ask::Agent::Session.new(
  model: "gpt-4o",
  tools: tools,
  plan_mode: true
  # plan_mode: { read_only_tools: %w[read glob grep web_search] } — custom
)

session.run("Investigate the outage and propose a fix")
# In plan mode, non-read-only tools return "Plan mode: only read-only tools..."
# The model researches, then calls:
#   exit_plan_mode(plan: "1. Check logs  2. Fix config  3. Restart")
session.plan_queue.pending_actions   # the plan awaits a human decision
session.plan_queue.approve(action.id)  # plan mode off → the agent executes
session.plan_queue.reject(action.id)   # stays in plan mode, feedback injected
```

- The gate runs before user hooks and the approval policy — in plan mode,
  mutating tools are blocked outright, never queued.
- Approve turns plan mode off and a follow-up turn executes the plan
  (`Events::PlanApproved`); reject keeps plan mode on and injects the
  rejection into the conversation (`Events::PlanRejected`).
- `Events::PlanProposed` fires when the plan is submitted. Default
  read-only allowlist: `read`, `glob`, `grep`, `web_search`.

## Durable Memory (v0.33.0+)

{: .new }
> New in ask-agent 0.33.0

Facts that outlive sessions — stored on the **same state adapter** as
sessions and checkpoints, so there's no new storage layer and no new
dependency:

<!-- docs-example: not-verified -->
```ruby
require "ask-agent"
require "ask-state-providers"

store = Ask::State::Providers::SQLite.new(path: "agent.db")
memory = Ask::Agent::Memory.new(state: store, namespace: "user:42")

session = Ask::Agent::Session.new(
  model: "deepseek-v4-flash",
  tools: tools,
  memory: memory
)

session.run("Deploy the fix")
# The model can call memory_write ("remember: deploy window is Tuesday")
# and memory_search to recall facts from earlier sessions.
```

- **How it works**: `Memory#write` saves a fact (identical content is
  deduped), `#search` does keyword substring matching ranked by matched
  terms (queries are punctuation-stripped), `#list`/`#delete`/`#count`
  round it out. Entries live under `memory:<namespace>:<id>` keys plus a
  JSON index — pure KV, so every backend (SQLite/Redis/Postgres/MySQL,
  custom adapters) works.
- **Namespaces isolate memory** — a support agent's facts never leak into a
  finance agent's; tenants share one backend safely.
- **Session integration**: the session injects `memory_write` (stamping the
  session id as provenance) and `memory_search` tools, and **injects
  relevant memories as a system message at run start** — session B starts
  knowing what session A learned. Agents without `memory:` are completely
  unaffected.
- The abstraction is domain-agnostic — memory holds facts about whatever
  your agent operates on, not code-specific data. Vector search (ask-rag)
  can slot in behind the same interface later, at scale.

### Learning (v0.35.0+)

{: .new }
> New in ask-agent 0.35.0

With `memory_learning: true`, the session **extracts durable facts
automatically** when it ends — the model no longer has to remember to call
`memory_write`:

```ruby
session = Ask::Agent::Session.new(
  model: "deepseek-v4-flash",
  memory: memory,
  memory_learning: true   # requires memory:
)

session.run("Help me set up the deploy pipeline")
# When the session ends, a MemoryExtractor reads the transcript, asks the
# model for durable facts ("deploy window is Tuesday", "the team uses
# kamal"), dedupes them against the store, and writes them with provenance.
```

- **How it works**: `MemoryExtractor` sends the memory-relevant messages
  (user + assistant, capped — oldest dropped) to the model with a
  configurable structured-output prompt; the returned facts are deduped
  (exact + near-duplicate via search), stamped `extracted: true` with the
  source session id, and capped at `max_candidates` (default 10).
- **Best-effort**: unparseable responses and failed calls yield an empty
  result — extraction never breaks the session.
- **Bounded memory**: `Memory.new(max_entries: 200)` prunes the oldest
  entries once a namespace exceeds the cap.

## Policies (Tool-Lifecycle Extensions)

Policies are opt-in, replaceable implementations of the tool-lifecycle hook
seam (`before_tool` / `after_tool`). The agent loop runs without them, and
you can swap in your own classes with the same signatures. Core mechanisms
stay on `Session` — the approval queue, the `:pending` result status, and
the `approval: true` option are core; `Policies::ApprovalPolicy` is the
reference classification policy wired on top of them.

Built-in policies (under `Ask::Agent::Policies`):

- **Permissions** — Enforce access modes (`:full_access`, `:read_only`, `:ask_before_changes`) on tool calls
- **RateLimiter** — Prevent runaway tool calls
- **AuditLog** — Immutable, append-only tool call log
- **ApprovalPolicy** — Queue approval-required tool calls into an `ApprovalQueue`

## Scheduler (Recurring Agent Runs)

Schedule agents to run on cron schedules or recurring intervals. Tasks run in background threads managed by `rufus-scheduler`.

```ruby
Ask::Agent.configure do |c|
  c.scheduler.every "5 minutes", name: "health-check" do
    Ask::Agent::Session.new(model: "deepseek-v4-flash").run("Check server health")
  end

  c.scheduler.cron "0 9 * * 1-5", name: "morning-report" do
    session = Ask::Agent::Session.new(model: "deepseek-v4-flash")
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
module HealthCheck
  class Agent < Ask::Agent::Definition
    model "deepseek-v4-flash"
    tools :bash, :read, :grep
    schedule "every 5 minutes"
  end
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
