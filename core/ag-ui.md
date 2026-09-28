---
layout: default
title: AG-UI Protocol
parent: Core Components
nav_order: 20
---

# ask-ag-ui

**Serve your ask-rb agent to any AG-UI chat frontend over SSE.** AG-UI (Agent-User Interaction) is the protocol frontends like assistant-ui and CopilotKit already speak: a run request goes out over HTTP, and the answer comes back as a stream of typed protocol events. ask-ag-ui is the server side of that conversation for the ask-rb ecosystem.

The gem is two halves, and both are public API. `Ask::AGUI::Emitter` is the seam that turns agent and session events into AG-UI frames — you drive one per run. `Ask::AGUI::Server` is a mountable Rack application serving the endpoints those frontends expect; you hand it a block that produces events, and it owns the socket and the framing.

Neither half needs Rails, and neither needs ask-agent.

```ruby
gem "ask-ag-ui"
```

## Quick Start

One emitter per run. Give it the run context, feed it events, write the frames it answers to your stream:

```ruby
require "ask-ag-ui"
require "json"

# Duck-typed stand-ins for the agent events the emitter matches by class
# name. ask-ag-ui never requires ask-agent, so anything with this shape works.
TurnStart = Data.define
ThinkingDelta = Data.define(:content)
TextDelta = Data.define(:content)
ToolCallDelta = Data.define(:name, :arguments, :id)
MessageEnd = Data.define(:tool_calls)
ToolExecutionEnd = Data.define(:name, :id, :result)
SessionEnd = Data.define(:result)

messages = [AgUiProtocol::Core::Types::UserMessage.new(id: "u1", content: "Hi")]
emitter = Ask::AGUI::Emitter.new(thread_id: "t1", run_id: "r1", messages: messages)

frames = [
  emitter.handle(TurnStart.new),
  emitter.handle(ThinkingDelta.new(content: "check the weather")),
  emitter.handle(TextDelta.new(content: "It is sunny")),
  emitter.handle(ToolCallDelta.new(name: "search", arguments: '{"q":"weather"}', id: "tc-1")),
  emitter.handle(MessageEnd.new(tool_calls: true)),
  emitter.handle(ToolExecutionEnd.new(name: "search", id: "tc-1", result: "sunny")),
  emitter.handle(SessionEnd.new(result: "done"))
].flatten

frames.map { |frame| JSON.parse(frame.delete_prefix("data: "))["type"] }
# => ["RUN_STARTED",
#  "REASONING_START",
#  "REASONING_MESSAGE_START",
#  "REASONING_MESSAGE_CONTENT",
#  "TEXT_MESSAGE_START",
#  "TEXT_MESSAGE_CONTENT",
#  "TOOL_CALL_START",
#  "TOOL_CALL_ARGS",
#  "REASONING_MESSAGE_END",
#  "REASONING_END",
#  "TEXT_MESSAGE_END",
#  "TOOL_CALL_END",
#  "TOOL_CALL_RESULT",
#  "RUN_FINISHED"]
```

Every frame comes back as one `"data: <json>\n\n"` string, ready to write straight to the response body. The emitter only translates and encodes — the transport owns the socket.

## The event vocabulary

Events are matched by **class name**, not by `is_a?`, so the emitter never depends on ask-agent internals. These are the real `Ask::Agent::Events::*` names, and any duck-typed object with the same class name and shape drives the same frames:

| Agent event | AG-UI frames |
|---|---|
| `TurnStart`, `SessionStart` | `RUN_STARTED` — the first one wins |
| `TextDelta` (`content`) | `TEXT_MESSAGE_START` → `TEXT_MESSAGE_CONTENT` per delta → `TEXT_MESSAGE_END` on `MessageEnd` |
| `ThinkingDelta` (`content`) | `REASONING_START` → `REASONING_MESSAGE_START` → `REASONING_MESSAGE_CONTENT` per delta → `REASONING_MESSAGE_END` → `REASONING_END` on `MessageEnd` |
| `ToolCallDelta` (`name`, `arguments`, `id`) | `TOOL_CALL_START` once per `id` → `TOOL_CALL_ARGS` per non-empty delta |
| `ToolExecutionStart` | `TOOL_CALL_START` for a call the stream never announced |
| `ToolExecutionEnd` (`name`, `id`, `result`) | `TOOL_CALL_END` if still open, then `TOOL_CALL_RESULT` |
| `MessageEnd`, `TurnEnd` | close whatever text, reasoning, and tool call is still open — the run stays open |
| `SessionEnd` | `RUN_FINISHED` — the first one wins |
| `Error` (`error`) | `RUN_ERROR` |
| anything else | one generic `CUSTOM` frame |

Only *empty* deltas are dropped. A single space is content: dropping it would fuse the words around it into `due45 days`.

`MessageEnd` and `TurnEnd` have no AG-UI counterpart of their own — they only close what is still open. The next turn streams on under the same run.

Three methods drive the endings by hand, and all three are idempotent: `#start` opens the run, `#finish` closes it, and `#fail` closes it with an error. `#fail` takes an exception, a message string, or a duck-typed object answering `error`.

Every frame is built with `AgUiProtocol::Core::Events::*` and encoded with `AgUiProtocol::Encoder::EventEncoder`. Event JSON is never hand-rolled.

## Drive it yourself

You only need the emitter when the transport is yours — an existing controller, a custom socket, a non-HTTP surface. Parse the run input with `Ask::AGUI::Run.parse`, hand the emitter the run context, and write each frame as it arrives:

<!-- docs-example: not-verified -->
```ruby
class RunsController < ApplicationController
  def create
    run = Ask::AGUI::Run.parse(params[:id], request.body.read)
    emitter = Ask::AGUI::Emitter.new(
      thread_id: run.thread_id, run_id: run.run_id, messages: run.messages
    )

    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"

    # The host owns the agent: `agent_events` is your own enumerable of
    # agent events, from a session, a graph, or a provider stream.
    self.response_body = Enumerator.new do |stream|
      emitter.start.each { |frame| stream << frame }
      agent_events(run).each do |event|
        emitter.handle(event).each { |frame| stream << frame }
      end
      emitter.finish.each { |frame| stream << frame }
    end
  end
end
```

`Run.parse` raises `Ask::AGUI::Run::InvalidError` on malformed JSON or a missing `threadId` / `runId`, so answer that with a `400`. Messages, tools, and context are coerced to their `AgUiProtocol::Core::Types` counterparts on a best-effort basis — an entry that will not coerce is skipped, never fatal. `state` and `forwarded_props` are opaque and ride through verbatim.

If a host block raises mid-run, call `emitter.fail(e)` so the client still gets a `RUN_ERROR` frame instead of a dropped connection.

## Mount the server

Most apps never touch the emitter directly. `Ask::AGUI::Server` is the conventional surface third-party AG-UI clients expect, and it is a plain Rack application — an enumerable response body, no async or Falcon requirement. It works under any Rack server.

The constructor requires a run-handler block and raises `ArgumentError` without one. The block receives the parsed `Ask::AGUI::Run` and answers an enumerable of the same agent events the emitter handles:

<!-- docs-example: not-verified -->
```ruby
# config.ru
require "ask-ag-ui"

run Ask::AGUI::Server.new(agent_id: "assistant", description: "Docs helper") do |run|
  MyAgent.events_for(run)
end
```

In Rails, `mount` it where CopilotKit expects it. Routes match on trailing path segments, so the same app works standalone and mounted:

<!-- docs-example: not-verified -->
```ruby
# config/routes.rb
mount Ask::AGUI::Server.new(agent_id: "assistant") { |run| MyAgent.events_for(run) },
  at: "/api/copilotkit"
```

A block may answer a lazy enumerator — the response body pulls events only as it streams, so a long run streams under any Rack server. Every run opens with `RUN_STARTED` and closes with `RUN_FINISHED` or `RUN_ERROR`, even when the host answers no events at all or raises partway through.

### What each endpoint answers

| Method & path | Answers |
|---|---|
| `GET /info` | `200` JSON: the agents map (name, class, capabilities), the transport `mode`, and the gem version |
| `POST /agent/:id/run` | `200` `text/event-stream` — the run's SSE frames as the block's events arrive. Malformed input answers `400` with `{"error": "Invalid request body", "details": ...}` |
| `POST /agent/:id/connect` | `200` `text/event-stream` — every frame recorded for the thread, replayed in order, or an immediately-completed empty stream when there is nothing to replay |
| `POST /agent/:id/stop/:thread_id` | `200` JSON `{"stopped": true}` — flags the run for cooperative cancel; the run loop checks the flag between events |
| `OPTIONS` | `204` CORS preflight |
| anything else | `404` JSON `{"error": "Not found"}` |

`/info` needs no agent and no network, so you can read the real envelope straight off the app:

```ruby
require "ask-ag-ui"
require "json"
require "stringio"

app = Ask::AGUI::Server.new(agent_id: "assistant", description: "Docs helper") do |run|
  [] # stands in for the host's agent events
end

_status, headers, body = app.call(
  "REQUEST_METHOD" => "GET", "PATH_INFO" => "/info", "rack.input" => StringIO.new("")
)
headers["content-type"]
# => "application/json"
JSON.parse(body.first)
# => {"agents" =>
#   {"assistant" =>
#     {"name" => "assistant",
#      "className" => "BuiltInAgent",
#      "capabilities" =>
#       {"identity" =>
#         {"name" => "assistant",
#          "description" => "Docs helper",
#          "version" => "0.1.0"},
#        "transport" => {"streaming" => true},
#        "tools" => {"supported" => true, "clientProvided" => true},
#        "reasoning" => {"supported" => true, "streaming" => true}},
#      "description" => "Docs helper"}},
#  "mode" => "sse",
#  "version" => "0.1.0"}
```

The default capabilities advertise exactly what the emitter drives: SSE transport, client-provided tools, and streaming reasoning. Pass your own `AgUiProtocol::Core::Capabilities::AgentCapabilities` to override them, or `agent_class_name:` to name a real class on `/info`.

## Two things that bite

### A CUSTOM frame is named after the event's class

Everything the emitter does not recognize rides a single `CUSTOM` frame: `name` is the event's class name, and `value` is its `to_h`. That is how an app's own state vocabulary — todos, plans, compaction — reaches a frontend without the gem knowing anything about it.

The `name` is the **demodulized** class name: the last segment, so `MyApp::TodoUpdated` arrives as `TodoUpdated`. The class name is also the only lever. If your frontend expects a `"todo.updated"` frame, you name your event class that way — ask-ag-ui 0.1.0 has no separate `name:` option on `Emitter.new`:

```ruby
require "ask-ag-ui"
require "json"

module MyApp
  TodoUpdated = Data.define(:todos)
end

emitter = Ask::AGUI::Emitter.new(thread_id: "t1", run_id: "r1")
frame = emitter.handle(MyApp::TodoUpdated.new(todos: [{ id: "1", content: "write the guide" }])).first
JSON.parse(frame.delete_prefix("data: "))
# => {"type" => "CUSTOM",
#  "name" => "TodoUpdated",
#  "value" => {"todos" => [{"id" => "1", "content" => "write the guide"}]}}
```

A `Data` class turns its members into the value, so a frontend reads `value.todos`. A real `Ask::Agent::Events::TodoUpdated`, `PlanProposed`, or `CompactionStart` off an ask-agent session rides the same path.

### The in-memory run store lives in one process

`Ask::AGUI::Server` records every frame per thread so `/connect` can replay it and `/stop` can find the run. The default store, `Ask::AGUI::RunStore::InMemory`, keeps those frames in **this process's memory only**.

Two processes — two Puma workers, two machines — cannot see each other's runs. Replay and stop only work while the client keeps hitting the same process, so `/connect` can answer an empty stream and `/stop` flags a run that is not there. Past one process, back both with a shared store, or pass `store: nil` to be explicitly stateless:

```ruby
# Stateless: /connect completes immediately, /stop only acknowledges.
Ask::AGUI::Server.new(agent_id: "assistant", store: nil) { |run| [] }
```

The store interface is duck-typed — anything answering `begin_run`, `record`, `finish_run`, `replay`, `request_stop`, and `stop_requested?` works, so a Redis or database store drops in without touching the server. The in-memory one is mutex-guarded, so threads inside a single process are safe.

## Next steps

- [Build the agent that feeds it](/ask-docs/core/agent) — sessions, tools, and the `Ask::Agent::Events::*` vocabulary the emitter matches.
- [UI Kit](/ask-docs/core/ui-kit) — Web Components for a chat surface on the other end of the stream.
- [Session Protocol](/ask-docs/core/session-protocol) and [App Server](/ask-docs/core/app-server) — the same ecosystem over stdio instead of HTTP.
- [Permissions](/ask-docs/core/permissions) — gate the tool calls whose `TOOL_CALL_*` frames you are streaming.
- [The full gem index](/ask-docs/reference/gems)
