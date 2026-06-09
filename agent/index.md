---
layout: default
title: ask-agent
nav_order: 3
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

## Events

```ruby
session.on_event do |event|
  case event
  when Ask::Agent::Events::TextDelta
    print event.content
  when Ask::Agent::Events::ToolExecutionStart
    puts "\nRunning #{event.name}..."
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
