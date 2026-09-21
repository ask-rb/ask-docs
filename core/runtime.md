---
layout: default
title: Execution Runtime
parent: Core Components
nav_order: 3
---

# Execution Runtime

An agent decides that a tool should run. The execution runtime carries that
decision to the backend that actually runs it, then brings back one predictable
result. This is the seam between “the model requested this” and “the command,
Ruby method, or remote tool finished.”

Use the runtime when you are building an agent framework, adding a new tool
backend, or running tools outside `ask-agent`. If you only need to define a
tool for an existing agent, start with [Tools & Execution](/ask-docs/core/tools).

## Run a sandbox command through the runtime

The fastest way to see the pieces working together is a sandbox executor. It
uses the configured Local, Docker, Daytona, or Cloudflare provider and exposes
the same runtime contract regardless of which provider you choose.

```ruby
gem "ask-runtime"
gem "ask-sandbox-providers"
```

```ruby
require "ask-sandbox-providers"

executor = Ask::Sandbox::RuntimeExecutor.new
call = Ask::Runtime::ToolCall.new(
  id: "tc_001",
  tool_name: "sandbox.execute",
  input: { command: ["ruby", "-e", "puts 1 + 1"] },
  session_id: "session_42",
  turn: 1
)
context = Ask::Runtime::ExecutionContext.new(
  session_id: "session_42",
  turn: 1,
  workspace: Dir.pwd
)

result = executor.execute(call, context: context)
result.success?       # => true
result.output[:stdout] # => "2\n"
```

The runtime does not know whether the command ran in a subprocess or a remote
sandbox. It only knows the call, its context, the normalized result, and the
lifecycle events emitted while the backend works.

## The journey of a tool call

Think of a runtime execution as a small journey with four stops:

```
ToolCall ──▶ ExecutionContext ──▶ ToolExecutor ──▶ ToolResult
   │                │                    │              │
   └────────────── correlation ─────────┴──── events ───┘
```

### `ToolCall`: what should happen?

`ToolCall` is an immutable request. It carries the tool name, structured input,
an identifier, and correlation fields such as session and turn. During
execution, adapters create snapshots with `state: :running` and then one of
the terminal states: `:completed`, `:failed`, `:cancelled`, or `:timed_out`.

### `ExecutionContext`: under whose rules?

`ExecutionContext` carries the information that should not be mixed into tool
arguments:

```ruby
context = Ask::Runtime::ExecutionContext.new(
  session_id: "session_42",
  turn: 3,
  caller_id: "coding_agent",
  workspace: "/work/my-app",
  capabilities: [:read_files, :run_tests],
  metadata: { user_id: 7 }
)
```

The context also owns the cancellation token and event sink. A backend can
read `context.workspace` as its default working directory without asking the
model to put that policy in its tool input.

### `ToolExecutor`: where does it run?

An executor implements one method:

```ruby
execute(tool_call, context: nil) # => Ask::Runtime::ToolResult
```

The built-in adapters cover the three common boundaries:

| You are executing through | Use | What it gives you |
|---|---|---|
| The Ask agent loop | `Ask::Agent::ToolExecutor` | Existing tool registry, retries, parallel execution, and runtime events |
| An MCP server | `Ask::MCP::RuntimeExecutor` | MCP response normalization and runtime lifecycle events |
| A sandbox provider | `Ask::Sandbox::RuntimeExecutor` | Command execution through Local, Docker, Daytona, or Cloudflare |

The adapters are additive. Existing `Ask::Tool#call`, `Ask::MCP::Client#call_tool`,
and `Ask::Sandbox.provider.call` APIs continue to work on their own.

### `ToolResult`: what came back?

Every runtime execution returns a `ToolResult` with one outcome vocabulary:

```ruby
result.success?   # completed normally
result.failure?   # backend or tool failure
result.cancelled? # cancellation won
result.timeout?   # the backend exceeded its limit

result.output         # successful output
result.error_message  # failure, cancellation, or timeout message
result.duration       # elapsed seconds
```

For a sandbox command, the successful output is a hash containing `stdout`,
`stderr`, `exit_code`, and `timed_out`. For MCP, it is the normalized MCP
content. For an Ask tool, it is the tool’s `Ask::Result` payload.

## Watch the lifecycle

The runtime emits immutable event objects through an `EventSink`. Subscribe to
the events that matter to your host:

<!-- docs-example: not-verified -->
```ruby
require "ask-sandbox-providers"

sink = Ask::Runtime::EventSink.new
sink.on(:tool_started) do |payload|
  event = payload[:event]
  puts "Starting #{event.tool_name} (#{event.tool_call_id})"
end
sink.on(:tool_completed) do |payload|
  event = payload[:event]
  puts "Finished in #{event.duration.round(3)}s"
end
sink.on(:tool_failed) do |payload|
  puts "Tool failed: #{payload[:event].error}"
end

context = Ask::Runtime::ExecutionContext.new(event_sink: sink)
Ask::Sandbox::RuntimeExecutor.new.execute(call, context: context)
```

The event sequence is `tool_started` followed by exactly one terminal event:
`tool_completed`, `tool_failed`, `tool_cancelled`, or `tool_timed_out`. Each
terminal event carries the final `ToolCall`, the normalized `ToolResult`, the
context, and the elapsed duration.

### Forward events to instrumentation

If your application already uses `ActiveSupport::Notifications`, let
`ask-instrumentation` bridge the runtime events into the same event stream as
LLM calls:

```ruby
gem "ask-instrumentation"
```

```ruby
require "ask/instrumentation"
require "ask/instrumentation/runtime_adapter"

Ask::Instrumentation.subscribe("tool.completed.ask") do |event|
  puts "#{event.payload[:tool_name]} took #{event.duration}ms"
end

sink = Ask::Instrumentation.install_runtime_sink
context = Ask::Runtime::ExecutionContext.new(event_sink: sink)
```

See [Observability & Events](/ask-docs/production/observability) when you
want to add metrics, tracing, or durable audit records.

## Stop work safely

Cancellation is cooperative. Cancel before an executor starts and it will not
call the backend:

```ruby
canceller = Ask::Runtime::Canceller.new
context = Ask::Runtime::ExecutionContext.new(canceller: canceller)

canceller.cancel
result = executor.execute(call, context: context)
result.cancelled? # => true
```

If a backend has its own hard timeout, pass it in the tool input or provider
configuration. The sandbox Local provider terminates the entire process group
when its timeout expires and the runtime maps that result to `timeout?`.

## Build your own executor

Keep a custom executor narrow: accept a `ToolCall`, read policy from the
context, call one backend, and normalize its response. Do not make every tool
know about MCP, subprocesses, or instrumentation.

```ruby
class GreetingExecutor
  include Ask::Runtime::ToolExecutor

  def execute(tool_call, context: nil)
    context ||= Ask::Runtime::ExecutionContext.new
    return Ask::Runtime::ToolResult.cancelled("Cancelled") if context.cancelled?

    name = tool_call.input.fetch(:name)
    Ask::Runtime::ToolResult.success(data: "Hello, #{name}!")
  rescue KeyError => error
    Ask::Runtime::ToolResult.failure(error.message)
  end
end
```

For a production adapter, emit the standard lifecycle events and preserve the
call ID, session, turn, terminal state, and duration. The runtime ships a
contract helper so you can verify that behavior rather than copying the
checklist by hand.

## Test an executor like the built-ins

The contract helper is an optional test dependency surface. Include it in a
Minitest class and provide representative successful, failed, and cancelled
calls:

<!-- docs-example: not-verified -->
```ruby
require "ask/runtime/testing"

class GreetingExecutorTest < Minitest::Test
  include Ask::Runtime::Testing::ExecutorContract

  def test_executor_contract
    assert_conforms_to_runtime_contract(
      GreetingExecutor.new,
      success_call: call(name: "Ada"),
      failure_call: call,
      cancelled_call: call(name: "Ada"),
      context_factory: ->(event_sink:, canceller: nil) {
        Ask::Runtime::ExecutionContext.new(
          event_sink: event_sink, canceller: canceller
        )
      }
    )
  end
end
```

The helper checks result normalization, duration, success event ordering,
failure and cancellation terminal events, and correlation metadata. Keep
backend-specific cases—MCP content shapes, sandbox exit codes, or tool retry
rules—in the adapter’s own test suite.

## Choose the right layer

- Start with [`Ask::Tool`](/ask-docs/core/tools) when you are defining a
  capability.
- Use [`ask-agent`](/ask-docs/core/agent) when a model should choose and
  sequence tools.
- Use [`ask-mcp`](/ask-docs/core/mcp) when another process or agent owns the
  tool server.
- Use [Sandbox Providers](/ask-docs/core/sandbox) when untrusted or isolated
  code needs to run.
- Use [Observability & Events](/ask-docs/production/observability) when the
  execution journey must be visible in production.

## Next steps

- [Tools & Execution](/ask-docs/core/tools) — define tools and understand
  `Ask::Result`.
- [The Agent Loop](/ask-docs/core/agent) — let an LLM select and sequence
  tools.
- [MCP Client](/ask-docs/core/mcp) — execute tools owned by MCP servers.
- [Sandbox Providers](/ask-docs/core/sandbox) — choose the execution
  environment for commands and code.
- [ask-runtime on GitHub](https://github.com/ask-rb/ask-runtime) — source,
  changelog, and contract tests.
