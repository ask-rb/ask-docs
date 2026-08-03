---
layout: default
title: App Server (JSON-RPC)
parent: Core Components
nav_order: 12
---

# ask-app-server

**Expose an ask-rb agent as an app-server — a long-lived process that speaks
the standard app-server protocol over stdio.** The app-server protocol is a
vendor-neutral interface for driving an agent as a service: JSON-RPC 2.0 over
newline-delimited JSON, with sessions, streamed events, approvals, and turn
lifecycle. Any client that implements the protocol can drive your agent — an
IDE extension, a chat UI, a bot, a CI script — and the client never needs to
know it's talking to Ruby.

The same protocol is what several coding agents use behind their own
app-servers (OpenAI's Codex app-server is one well-known implementation), and
existing app-server clients and SDKs understand it out of the box.
ask-app-server isn't an extension of any of them — it simply speaks the
standard, so whatever you build on top of it is yours.

```ruby
gem "ask-app-server"
```

## What you can build

Because the protocol is a standard, one server unlocks every client surface
— you don't write a separate integration per client:

- **IDE extensions and editors** — stream `model.streaming` deltas and
  `tool.updated` events into an editor surface over stdio or a socket, the
  same way agent–editor integrations work today
- **Custom chat UIs and desktop apps** — stream `model.streaming` deltas and
  `tool.updated` events into your own interface, with the full turn lifecycle
- **Bots and assistants** — drive sessions programmatically from any runtime
  that can spawn a subprocess and pipe JSON
- **Automation and CI pipelines** — create a session, send a task, poll for
  events, and read the completed turn, all from a script
- **Your own client or SDK, in any language** — the wire format is plain
  JSON-RPC 2.0 over newline-delimited JSON on stdio; nothing Ruby-specific

App-server protocols are built for deep product integration — sessions,
conversation history, approvals, and streamed agent events — the things a
plain one-shot API call can't give you.

## Quick Start

Start the server — it reads JSON-RPC from stdin and writes to stdout:

```bash
ask-app-server
```

From another process, send JSON-RPC requests:

```json
{"id":1, "method":"session/create", "params":{"workspace":{"workspacePath":"."}}}
{"id":2, "method":"session/send",  "params":{"sessionId":"...", "content":"List files in this directory"}}
```

## Protocol

### Methods

| Method | Description |
|---|---|
| `initialize` | Handshake; returns server capabilities |
| `session/create` | Create a new agent session |
| `session/list` | List active sessions |
| `session/resume` | Resume an existing session |
| `session/subscribe` | Subscribe to streaming events |
| `session/send` | Send a message to a session |
| `session/events` | Poll for events after a sequence number |
| `session/abort` | Abort the current turn |
| `workspace/readState` | Read model and workspace settings |

### Events (server → client notifications)

| Event | When |
|---|---|
| `turn.started` | A new turn begins processing |
| `model.streaming` | Text delta from the model |
| `tool.updated` | Tool execution started/updated/completed/failed |
| `turn.completed` | Turn finished successfully |
| `turn.failed` | Turn ended with an error |

Event payloads are delivered as `session/event` notifications on subscribed
sessions. The server also sends `interaction/requestPermission` when a
blocked tool needs approval and `interaction/requestUserInput` when it needs
input from the user — so your client can build approval and prompt flows into
its own UI.

## Clients

Any client that speaks the app-server protocol can connect — including
existing app-server SDKs, such as OpenAI's `openai-codex` (Python) and
`@openai/codex-sdk` (TypeScript), which spawn an app-server subprocess and
drive it over stdio. Or write your own client in any language: the protocol
is documented and the wire format is plain JSON-RPC.

## Configuration

Flags: `--version`, `--help`, `--config PATH`.

The config file is searched in order: `ASK_APP_SERVER_CONFIG` env var, then
`./.ask-app-server.json`, then `~/.ask-app-server/config.json`.

Environment variables:

| Variable | Default | Description |
|---|---|---|
| `ASK_APP_SERVER_CONFIG` | auto-detected | Path to the config file |
| `ASK_APP_SERVER_MODEL` | `opencode_go/deepseek-v4-flash` | Model identifier (overrides config file) |
| `ASK_APP_SERVER_PERMISSIONS` | `on_request` | Permission mode (`on_request`, `never`) |
| `DEBUG` | unset | Set to `1` for debug logging |

## Next Steps

- [Build an agent to serve](/ask-docs/core/agent)
- [Credential resolution](/ask-docs/core/auth)
- [The tool framework](/ask-docs/core/tools)
