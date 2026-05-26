---
layout: default
title: ask-agent
nav_order: 3
---

# ask-agent

**The agent loop gem.** Think → act → observe → repeat.

```ruby
gem "ask-agent"
```

## Quick start

```ruby
agent = Ask::Agent.new(
  provider: Ask::Provider::OpenAI.new(api_key: "..."),
  model: "gpt-4o",
  tools: Ask::Tools.all
)

agent.run("List files in /tmp") do |event|
  case event
  in Ask::Agent::Event::Chunk(content:) then print content
  in Ask::Agent::Event::ToolCalled(name:, arguments:) then log_tool_call(name, arguments)
  in Ask::Agent::Event::Complete(response:) then log_done(response.usage)
  end
end
```

## Sessions

Sessions provide persistence and state management across turns.

```ruby
session = Ask::Agent::Session.new(
  provider: ...,
  model: "deepseek-v4-flash",
  tools: Ask::Tools.all,
  persistence: :in_memory  # or :active_record (Rails)
)
session.run("Fix the bug")
session.messages  # full conversation
session.save      # persist
```

## Extensions

Extensions hook into every lifecycle event. Loaded automatically from `~/.ask-agent/extensions/` and
`./.ask-agent/extensions/`.

```ruby
Ask::Agent::Extension.new do
  name "Permission Gate"
  description "Require approval for destructive operations"

  on :before_tool_call do |context|
    if %w[write edit delete].include?(context.name)
      context.halt unless confirm("Allow #{context.name} with #{context.arguments}?")
    end
  end
end
```

### Built-in extensions

- **PermissionGate** — require approval for dangerous tools
- **RateLimiter** — prevent runaway tool calls
- **AuditLog** — immutable record of every tool call

## Hooks reference

| Event | Fires | Can |
|-------|-------|-----|
| `before_tool_call` | Tool about to run | Block, mutate args |
| `after_tool_call` | Tool finished | Modify result |
| `before_request` | Before HTTP request | Modify payload |
| `after_response` | After HTTP response | — |
| `chunk` | Token received | — |
| `compacting` | Before compaction | Cancel, provide custom strategy |
