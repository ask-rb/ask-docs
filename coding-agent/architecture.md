---
layout: default
title: Architecture
parent: Coding Agent
nav_order: 4
---

# Architecture

The harness is a thin shell over the ask-rb ecosystem. The agent loop,
tools, sandboxing, and adapters all come from existing gems; the harness
adds the server, the store, and the browser UI.

```
Browser (PWA) ──SSE──> Server (Roda) ──> AgentRunner ──> ask-coding-providers
                                                          ├─ ask_agent (default)
                                                          └─ acp / codex / claude
                └── SQLite (ask-state-providers) <── Store
```

## Components

| Component | File | Purpose |
|---|---|---|
| `Server` | `lib/ask/coding_harness/server.rb` | Roda app: REST + SSE endpoints, static PWA, SPA fallback |
| `AgentRunner` | `lib/ask/coding_harness/agent_runner.rb` | Turns: maps conversations to adapter sessions, streams events, persists outcomes |
| `Store` | `lib/ask/coding_harness/store.rb` | Conversation persistence on `ask-state-providers` (SQLite) |
| `EventTranslator` | `lib/ask/coding_harness/event_translator.rb` | Normalizes adapter events into one browser schema |
| `Runner` | `lib/ask/coding_harness/runner.rb` | Headless runs (`ach run`) |
| `DemoAdapter` | `lib/ask/coding_harness/demo_adapter.rb` | Scripted agent for keyless evaluation (`ach demo`) |
| `CLI` | `lib/ask/coding_harness/cli.rb` | `ach` / `ask-coding-harness` executables |

## The event schema

Adapters stream events in their own vocabularies (the ask_agent adapter
emits `model.streaming`, `tool.use`, `approval.required`, ...; ACP
adapters emit a basic subset). `EventTranslator` maps them all into one
browser-friendly schema over SSE:

| Event | Data |
|---|---|
| `turn.started` | — |
| `message.delta` / `message.thinking` | `{ delta }` |
| `tool.start` / `tool.delta` / `tool.end` | `{ id, name, args }` / `{ id, partial }` / `{ id, name, output, isError, durationMs }` |
| `approval.required` / `approval.updated` | `{ id, toolName, args, message }` / `{ id, status }` |
| `plan.proposed` / `plan.approved` / `plan.rejected` | `{ plan }` |
| `todos.updated` | `{ todos }` |
| `turn.completed` / `turn.failed` / `turn.aborted` | `{ response }` / `{ error }` / — |

The same events drive the PWA and the `ach run` transcript.

## Turns and approvals

A turn starts on `POST /api/chat` and the SSE stream stays open until the
turn fully settles. When a tool queues for approval, the turn pauses:
approving or rejecting from any thread resumes it, and follow-up turns
stream to the same connection. `ACH_TURN_TIMEOUT` bounds how long a turn
waits before aborting.

## The frontend

The PWA lives in `web/` (Svelte 5 + Vite) and builds into `public/`, which
ships inside the gem. Reusable components come from
[ask-ui-kit](/ask-docs/core/ui-kit): `ask-diff`, `ask-tool-approval`,
`ask-todo-list`, `ask-plan`, and `ask-terminal-output` are all upstream,
so other projects can reuse them without the harness. During development
the build imports ask-ui-kit from source via a vite alias.

## Extending

- **New tools** — add them via the harness config (`c.tools = [...]`) and
  the tool registry in `AgentRunner::TOOL_CLASSES`; anything that
  subclasses `Ask::Tool` works.
- **New coding agents** — implement (or reuse) an `ask-coding-providers`
  adapter: `create_session`, `send_and_stream`, and optionally the
  approval controls. Set `ACH_ADAPTER` to its registered name.
- **New UI** — the event schema is the contract; build any client that
  speaks it (the `ach run` transcript is one such client).
