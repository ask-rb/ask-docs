---
layout: default
title: App Server (JSON-RPC)
parent: Core Components
nav_order: 12
---

# ask-app-server

**Expose an ask-rb agent as an app-server — a long-lived process that speaks
the standard JSON-RPC app-server protocol over stdio.** The app-server
protocol is the interface OpenAI's Codex app-server uses to power rich
clients: the Codex VS Code extension ships on it, and OpenAI's official
`openai-codex` (Python) and `@openai/codex-sdk` (TypeScript) SDKs drive
agents through it. ask-app-server speaks the same protocol, so any client
that can drive an app-server can drive your ask-rb agent.

```ruby
gem "ask-app-server"
```

## What you can build

Because the protocol is a standard, one server unlocks every client surface
— you don't write a separate integration per client:

- **IDE extensions and editors** — the same interface that powers the Codex
  VS Code extension; connect an editor to your agent over stdio or a socket
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

Any app-server client can connect. That includes OpenAI's official Codex
SDKs (`openai-codex` for Python, `@openai/codex-sdk` for TypeScript), which
spawn an app-server subprocess and drive it over stdio — or write your own
client in any language: the protocol is documented and the wire format is
plain JSON-RPC.

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
