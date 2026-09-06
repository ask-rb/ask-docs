---
layout: default
title: Session Protocol
parent: Core Components
nav_order: 14
---

# Session Protocol

One wire contract for every ask client — terminal, web console, bot, IDE. `ask-session-protocol` defines the canonical session event vocabulary, the resolvable interactions (approvals, plan proposals, user input), the client-to-host methods, protocol versioning, and the generated JSON Schema — so the host and every client evolve independently against the same artifact.

```ruby
gem "ask-session-protocol"
```

## Why it exists

The agent runtime used to translate its events into three incompatible wire shapes (app-server events, harness SSE events, adapter events). This gem replaces that drift with one versioned definition.

```
              ask-agent (session runtime)
                        │
         ask-session-protocol  ← this gem
         events · interactions · methods · versions · JSON Schema
                        │  the only crossing artifact
              ask-app-server (THE HOST)
        transports: in-process | stdio | unix socket | SSE
               │
     terminal TUI · web console · bots · IDE integrations
```

It has no runtime, no transports, and no session logic — it is the contract both sides validate against.

## The pieces

| File | What it defines |
|---|---|
| `Ask::SessionProtocol::Events` | Canonical event types for turns, tool calls, approvals, compaction |
| `Ask::SessionProtocol::Interactions` | Resolvable interactions: approvals, plan proposals, user input |
| `Ask::SessionProtocol::Methods` | Client → host methods (`session/create`, `session/send`, `session/approve`, …) |
| `Ask::SessionProtocol::Client` | Shared client that speaks the protocol (used by `ask-terminal`) |
| `Ask::SessionProtocol::Host` | Shared host logic that speaks the protocol (used by `ask-app-server`) |
| `Ask::SessionProtocol::Schema` | Generated JSON Schema artifacts for validation |
| `Ask::SessionProtocol::PROTOCOL_VERSION` | `"1.0"` — bump minor for additive, major for breaking |

## Delivery kinds

How a subscriber receives events for an existing session:

| Kind | Behavior |
|---|---|
| `live` | Push events as they happen; no replay |
| `replay` | Replay the event log from `after_seq` first, then push new events |
| `web-remote-replayable` | Replay semantics tuned for web/remote clients — snapshot-friendly and resumable |

## Use it

Build a client or a host by leaning on the shared pieces:

```ruby
require "ask/session_protocol"

# Validate an event payload at the boundary
Ask::SessionProtocol::Schema.validate!(payload)

# Check protocol compatibility
Ask::SessionProtocol::PROTOCOL_VERSION  # => "1.0"
```

To run the full loop, use the host and a client:

- **Host:** [`ask-app-server`](/ask-docs/core/app-server) — the only implementation that owns sessions, transports, and the event log.
- **Client:** [`ask-terminal`](/ask-docs/core/terminal) — the first thin client; a web or bot client works the same way.

## Next steps

- [App Server](/ask-docs/core/app-server) — the host that implements the protocol
- [Terminal](/ask-docs/core/terminal) — the thin client that speaks it
- [ask-session-protocol on GitHub](https://github.com/ask-rb/ask-session-protocol) — schema artifacts and changelog
