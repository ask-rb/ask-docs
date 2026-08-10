---
layout: default
title: ACP Client & Server
parent: Core Components
nav_order: 12
---

# ask-acp

**The Agent Client Protocol (ACP) for Ruby — JSON-RPC 2.0 over stdio for
agent–client communication.** ACP is the wire protocol coding agents speak to
editors, CLIs, and other clients: a client sends JSON-RPC requests on stdin,
the agent streams events and responses on stdout. ask-acp gives you all three
sides of that relationship — a **client** that drives an ACP-speaking coding
agent as a subprocess, a **server** base class that makes your own Ruby agent
speak ACP, and a **replay client** that re-plays recorded interactions for
fast, deterministic testing.

ACP works in two directions:

- **Drive a coding agent** — spawn Codex, OpenCode, or any other ACP agent
  from Ruby, create sessions, stream prompts and tool calls, cancel turns.
- **Be a coding agent** — subclass `Ask::ACP::Server` and any ACP client (an
  editor integration, a CLI wrapper, your own tooling) can drive your Ruby
  agent without knowing it's Ruby.

Both directions are protocol, not framework — there is no shared agent loop
and no ask-rb dependency in the gem itself.

```ruby
gem "ask-acp"
```

## Quick Start

The fastest way in is the replay client: it reads a fixture of recorded
JSON-RPC messages instead of spawning a subprocess, so you get the full
session flow with instant, deterministic responses. This example writes a
small fixture, then drives a session end to end:

```ruby
require "ask-acp"

File.write("opencode.jsonl", <<~JSONL)
  {"response":{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentInfo":{"name":"OpenCode","version":"1.18.3"}}}}
  {"response":{"jsonrpc":"2.0","id":2,"result":{"session":{"id":"sess_1","status":"running","createdAt":"2026-08-10T10:00:00Z"}}}}
  {"notification":{"jsonrpc":"2.0","method":"text","params":{"sessionId":"sess_1","content":"I'll list the files first."}}}
  {"notification":{"jsonrpc":"2.0","method":"turn_complete","params":{"sessionId":"sess_1"}}}
  {"response":{"jsonrpc":"2.0","id":3,"result":{"status":"completed"}}}
JSONL

client = Ask::ACP::ReplayClient.new(fixture_path: "opencode.jsonl")
client.start
info = client.initialize!(client_name: "my-app", client_version: "0.1.0")
info
# => {"protocolVersion" => 1, "agentInfo" => {"name" => "OpenCode", "version" =>
# "1.18.3"}}

session = client.session_new(cwd: ".")
session
# => {id: "sess_1", status: "running", created_at: "2026-08-10T10:00:00Z"}

events = []
client.on_notification { |event| events << event["method"] }

client.session_prompt(session[:id], "What files are in this directory?")
events
# => ["text", "turn_complete"]
```

The API is identical for a live agent — only the fixture is replaced by a real
subprocess. More on that next.

## Talk to a real coding agent

`Ask::ACP::Client` spawns the agent CLI with `Open3` and speaks ACP over
stdio. The command is the one that puts the agent into ACP mode — for example
Codex's `codex acp` or OpenCode's `opencode acp`:
<!-- docs-example: not-verified -->
```ruby
require "ask-acp"

client = Ask::ACP::Client.new(command: ["codex", "acp"])
client.start
client.initialize!(client_name: "my-app", client_version: "0.1.0")

session = client.session_new(cwd: "/path/to/project")

# Stream prompt events as they arrive
client.session_prompt(session[:id], "Explain this codebase") do |event|
  puts "#{event[:method]}: #{event[:params].inspect}"
end

client.stop
```

The initialize handshake returns the agent's capabilities and any
authentication methods it requires (`authMethods`) — if the agent needs a
token before it will start a session, see
[Authentication & configuration](#authentication--configuration) below.

Agents that require auth are also covered by
[ask-coding-providers](https://github.com/ask-rb/ask-coding-providers), the
registry of coding-agent adapters (`:acp`, `:ask_agent`, `:claude`, `:codex`)
that knows how to spawn and authenticate each agent.

## Write your own ACP agent

`Ask::ACP::Server` is the other direction: a base class that reads JSON-RPC
from stdin, dispatches requests to your handlers, and writes responses back.
Subclass it, implement the `handle_*` methods you care about, and call `run`.

The full round trip — a Ruby agent as a subprocess, driven by a real
`Ask::ACP::Client` — looks like this:

```ruby
require "ask-acp"

# The agent script: a small ACP server, run as its own process.
agent = <<~RUBY
  require "ask-acp"

  class DocsAgent < Ask::ACP::Server
    def handle_session_new(params)
      { session: { id: "sess_docs", status: "running", createdAt: "2026-08-10T10:00:00Z" } }
    end

    def handle_session_prompt(params)
      send_text_delta(params["sessionId"], "Hello from my Ruby agent!")
      send_event("turn_complete", { sessionId: params["sessionId"] })
      { status: "completed" }
    end
  end

  DocsAgent.new.run
RUBY
File.write("docs_agent.rb", agent)

# Drive it from a real client, just like a Codex or OpenCode subprocess.
client = Ask::ACP::Client.new(command: [RbConfig.ruby, "-I", $LOAD_PATH.join(":"), "docs_agent.rb"])
client.start
info = client.initialize!(client_name: "my-app", client_version: "0.1.0")
info
# => {"protocolVersion" => 1,
#  "capabilities" => {},
#  "serverInfo" => {"name" => "ask-acp", "version" => "0.1.1"}}

session = client.session_new(cwd: ".")
session
# => {id: "sess_docs", status: "running", created_at: "2026-08-10T10:00:00Z"}

events = []
result = client.session_prompt(session[:id], "Hello!") { |event| events << event[:method] }
events
# => ["text", "turn_complete"]

result
# => {"status" => "completed"}

client.stop
```

Every `handle_*` method receives the request params (string keys) and its
return value becomes the response result. The defaults are all reasonable to
override:

| Handler | Default response |
|---|---|
| `handle_initialize(params)` | Protocol version, capabilities, server name/version |
| `handle_session_new(params)` | New random `sessionId`, status `"running"` |
| `handle_session_load(params)` | The requested session id, status `"running"` |
| `handle_session_list(params)` | `{ sessions: [] }` |
| `handle_session_resume(params)` | The requested session id, status `"running"` |
| `handle_session_close(params)` | `{}` |
| `handle_session_prompt(params)` | One text delta, then `turn_complete`, then `{ status: "completed" }` |
| `handle_session_cancel(params)` | `{}` |

During a prompt you stream progress before the final response with
`send_text_delta(session_id, content)` and `send_event(method, params)` — both
write JSON-RPC notifications to stdout. A client that never calls
`initialize!` or sends an unknown method gets a proper JSON-RPC error back:
`-32600` for handler exceptions, `-32601` for unknown methods.

## The session lifecycle

Sessions are the unit of work in ACP: you create one in a working directory,
send prompts into it, and can list, load, resume, fork, and close it. ask-acp
normalizes the raw JSON-RPC result into a consistent hash for the session
methods:

```ruby
require "ask-acp"

File.write("sessions.jsonl", <<~JSONL)
  {"response":{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1}}}
  {"response":{"jsonrpc":"2.0","id":2,"result":{"sessions":[{"id":"sess_1","status":"running","createdAt":"2026-08-10T10:00:00Z"},{"id":"sess_2","status":"completed","createdAt":"2026-08-09T09:00:00Z"}]}}}
  {"response":{"jsonrpc":"2.0","id":3,"result":{"session":{"id":"sess_1","status":"running","createdAt":"2026-08-10T10:00:00Z"}}}}
  {"response":{"jsonrpc":"2.0","id":4,"result":{"session":{"id":"sess_1","status":"running","createdAt":"2026-08-10T10:00:00Z"}}}}
  {"response":{"jsonrpc":"2.0","id":5,"result":{}}}
JSONL

client = Ask::ACP::ReplayClient.new(fixture_path: "sessions.jsonl")
client.start
client.initialize!(client_name: "my-app", client_version: "0.1.0")

list = client.session_list(cwd: ".")
list
# => [{id: "sess_1", status: "running", created_at: "2026-08-10T10:00:00Z"},
#  {id: "sess_2", status: "completed", created_at: "2026-08-09T09:00:00Z"}]

loaded = client.session_load("sess_1")
loaded
# => {id: "sess_1", status: "running", created_at: "2026-08-10T10:00:00Z"}

resumed = client.session_resume("sess_1")
resumed
# => {id: "sess_1", status: "running", created_at: "2026-08-10T10:00:00Z"}

client.session_close("sess_1")
client.running?
# => true
```

The full method set, with the params each sends:

| Method | Params | Returns |
|---|---|---|
| `session_new(cwd:, model:, tools:)` | `cwd`, optional `model`, optional `tools` | normalized session |
| `session_load(session_id)` | `sessionId` | normalized session |
| `session_list(cwd:)` | optional `cwd` | array of normalized sessions |
| `session_resume(session_id)` | `sessionId` | normalized session |
| `session_fork(session_id)` | `sessionId` | normalized session |
| `session_close(session_id)` | `sessionId` | raw result |

A normalized session is always `{ id:, status:, created_at: }` — status is one
of `completed`, `failed`, `cancelled`, `in_progress`.

## Streaming prompt events

`session_prompt` is the workhorse: it sends a prompt and streams the agent's
progress as events before the final response. The prompt can be a plain
string — ask-acp wraps it in a `ContentBlock` array for you — or an explicit
array of content blocks.

The streamed events are the `PROMPT_EVENTS`:

| Event | Meaning |
|---|---|
| `text` | A text delta from the agent |
| `tool_use` | The agent wants to call a tool |
| `tool_result` | A tool call finished |
| `turn_complete` | The turn finished successfully |
| `turn_failed` | The turn ended in an error |
| `session/update` | Session state changed |
| `session/request_permission` | The agent needs approval to act |
| `session/elicitation` | The agent needs input from the user |

With a live `Client`, pass a block — it's a temporary notification handler
that receives `{ method:, params: }` for each event. With the `ReplayClient`,
events are delivered to `on_notification` handlers instead (fixtures can't
know when your block was registered):

```ruby
require "ask-acp"

File.write("tool_events.jsonl", <<~JSONL)
  {"response":{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1}}}
  {"notification":{"jsonrpc":"2.0","method":"tool_use","params":{"sessionId":"sess_1","toolUse":{"id":"use_1","name":"read_file","input":{"path":"notes.md"}}}}}
  {"notification":{"jsonrpc":"2.0","method":"tool_result","params":{"sessionId":"sess_1","toolUseId":"use_1","result":"# Notes\\n- one\\n- two"}}}
  {"notification":{"jsonrpc":"2.0","method":"turn_complete","params":{"sessionId":"sess_1"}}}
  {"response":{"jsonrpc":"2.0","id":2,"result":{"status":"completed"}}}
JSONL

client = Ask::ACP::ReplayClient.new(fixture_path: "tool_events.jsonl")
client.start
client.initialize!(client_name: "my-app", client_version: "0.1.0")

seen = []
client.on_notification { |event| seen << event["method"] }

client.session_prompt("sess_1", "Read notes.md")
seen
# => ["tool_use", "tool_result", "turn_complete"]
```

While a prompt is running you can interrupt it from another thread with
`session_cancel(session_id)` — the agent decides what to do with the request,
and the prompt call will finish with whatever status it chooses.

## Handling agent → client methods

ACP is bidirectional: the agent can call *client* methods too — file access,
permission requests, terminal control. These arrive as notifications and land
in your `on_notification` handlers:

```ruby
require "ask-acp"

File.write("permission.jsonl", <<~JSONL)
  {"response":{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1}}}
  {"notification":{"jsonrpc":"2.0","method":"session/request_permission","params":{"sessionId":"sess_1","toolName":"bash","description":"Run `rm -rf /tmp/scratch`"}}}
  {"response":{"jsonrpc":"2.0","id":2,"result":{"status":"completed"}}}
JSONL

client = Ask::ACP::ReplayClient.new(fixture_path: "permission.jsonl")
client.start
client.initialize!(client_name: "my-app", client_version: "0.1.0")

requests = []
client.on_notification do |event|
  requests << event["params"] if event["method"] == "session/request_permission"
end

client.session_prompt("sess_1", "Clean up the scratch directory")
requests
# => [{"sessionId" => "sess_1", "toolName" => "bash", "description" => "Run `rm -rf
# /tmp/scratch`"}]
```

The full set of client methods the agent may send:

| Method | When the agent sends it |
|---|---|
| `fs/read_text_file` | It needs to read a file from the client's filesystem |
| `fs/write_text_file` | It wants to write a file |
| `session/update` | Session state changed |
| `session/request_permission` | It needs approval before acting |
| `session/elicitation` | It needs input from the user |
| `session/elicitation/complete` | An elicitation round finished |
| `terminal/create` | It wants a terminal |
| `terminal/output` | Terminal output to relay |
| `terminal/wait_for_exit` | It's waiting on a terminal process |
| `terminal/kill` / `terminal/release` | Terminal lifecycle |

A real client answers these — e.g. running `fs/read_text_file` and returning
the file contents, or surfacing a permission request to the user — so the
agent can keep working.

## Authentication & configuration

If the agent requires authentication, the initialize result carries
`authMethods` — the prompt for a token is yours to build. Once you have it,
send it with `authenticate`:
<!-- docs-example: not-verified -->
```ruby
require "ask-acp"

client = Ask::ACP::Client.new(command: ["opencode", "acp"])
client.start
info = client.initialize!(client_name: "my-app", client_version: "0.1.0")

if info["authMethods"] && !info["authMethods"].empty?
  token = prompt_for_token(info["authMethods"])   # your UI, your call
  client.authenticate(token: token, scheme: "bearer")
end

client.session_new(cwd: ".")
```

Per-session configuration is three methods, each a single JSON-RPC round
trip:

| Method | Params | Purpose |
|---|---|---|
| `session_set_config_option(session_id, key, value)` | `sessionId`, `key`, `value` | Set any agent config option |
| `session_set_mode(session_id, mode)` | `sessionId`, `mode` | Switch the agent's mode (e.g. plan vs. build) |
| `session_set_model(session_id, provider:, model:)` | `sessionId`, `provider`, `model` | Switch the model for a session |

Call them after `session_new`, before the next `session_prompt`. What options
and modes exist is up to the agent — the protocol just carries them.

## Testing with ReplayClient

`ReplayClient` is the same interface as `Client` minus the subprocess — it
reads a fixture of newline-delimited JSON records and answers requests in
order, instantly. It exists for deterministic tests and docs, and it makes
your agent code testable without an API key, a network, or even an installed
agent.

The fixture format is one record per line, three kinds:

```ruby
require "ask-acp"

File.write("hello.jsonl", <<~JSONL)
  {"request":{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":1}}}
  {"response":{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1}}}
  {"notification":{"jsonrpc":"2.0","method":"text","params":{"content":"Hi!"}}}
JSONL

client = Ask::ACP::ReplayClient.new(fixture_path: "hello.jsonl")
client.start
client.initialize!(client_name: "my-app", client_version: "0.1.0")
client.running?
# => true
```

- `{"request": ...}` — a request the client sent (informational; recorded for
  review)
- `{"response": ...}` — a response the agent sent; answers the next pending
  request
- `{"notification": ...}` — an async notification from the agent; delivered to
  `on_notification` handlers when a prompt is streamed

Because the client responds in record order, a fixture can encode an entire
session — including tricky sequences like a permission request mid-prompt —
and the test re-runs it identically every time.

To record a fixture from a real agent, the ask-acp repo ships
`bin/record_acp` (run `ruby bin/record_acp opencode fixtures/session.jsonl`
from a checkout) — it spawns the agent, runs a standard session flow, and
writes every message to a fixture file.

## Errors and timeouts

ask-acp raises `Ask::ACP::Error` (and its subclass `Ask::ACP::TimeoutError`)
for protocol-level problems:

- Calling any method before `start` raises `Ask::ACP::Error` ("ACP client not
  started. Call #start first.")
- Calling a session method before `initialize!` raises `Ask::ACP::Error`
  ("ACP not initialized.")
- JSON-RPC error responses become `Ask::ACP::Error` with the code and message
  from the agent.
- A request that gets no response within `request_timeout` seconds (default
  30) raises `Ask::ACP::TimeoutError`.

Spawning a command that doesn't exist raises at `start`:

```ruby
require "ask-acp"

client = Ask::ACP::Client.new(command: ["definitely-not-a-real-agent"])
begin
  client.start
rescue => e
  error = e
end
error.class
# => Errno::ENOENT
```

And a silent agent triggers the timeout:

```ruby
require "ask-acp"

agent = <<~RUBY
  require "ask-acp"

  class SlowAgent < Ask::ACP::Server
    def handle_initialize(params)
      sleep 5
    end
  end

  SlowAgent.new.run
RUBY
File.write("slow_agent.rb", agent)

client = Ask::ACP::Client.new(
  command: [RbConfig.ruby, "-I", $LOAD_PATH.join(":"), "slow_agent.rb"],
  request_timeout: 0.5
)
client.start
begin
  client.initialize!(client_name: "my-app", client_version: "0.1.0")
rescue => e
  error = e
end
error.class
# => Ask::ACP::TimeoutError

client.stop
```

`stop` closes stdin, terminates the subprocess, and fails every still-pending
request with `Ask::ACP::Error("process exited")`.

## Protocol reference

The `Protocol` module holds the constants and message helpers:

```ruby
require "ask-acp"

Ask::ACP::Protocol::PROTOCOL_VERSION
# => 1

Ask::ACP::Protocol::AGENT_METHODS[:session_new]
# => "session/new"

Ask::ACP::Protocol::STATUSES[:completed]
# => "completed"
```

| Constant | Contents |
|---|---|
| `PROTOCOL_VERSION` | `1` (v0.11.3 schema) |
| `AGENT_METHODS` | All client → agent methods (`initialize`, `authenticate`, `logout`, `session/*`) |
| `CLIENT_METHODS` | All agent → client methods (`fs/*`, `session/elicitation`, `terminal/*`) |
| `PROMPT_EVENTS` | The streamed prompt events (`text`, `tool_use`, `tool_result`, `turn_complete`, …) |
| `STATUSES` | `completed`, `failed`, `cancelled`, `in_progress` |

Plus builders for the wire format if you ever need them: `build_request`,
`build_notification`, `build_response`, `build_error`, `parse`, and
`serialize`.

## ACP, app-server, or MCP?

Three protocol gems, three jobs — they don't overlap much:

| You want to... | Use |
|---|---|
| Drive a coding agent (Codex, OpenCode) from Ruby | **ask-acp** client |
| Make your Ruby agent a first-class citizen of ACP clients (editors, CLIs) | **ask-acp** server |
| Expose an ask-rb agent to app-server clients (IDE extensions, chat UIs) | [ask-app-server](/ask-docs/core/app-server) |
| Discover and call tools on an MCP server — or expose your tools to MCP clients | [ask-mcp](/ask-docs/core/mcp) |
| Know how to spawn and authenticate each coding agent | [ask-coding-providers](https://github.com/ask-rb/ask-coding-providers) |

ACP and app-server are both JSON-RPC 2.0 over stdio, but they serve different
relationships: app-server is a service interface for *your* agent (sessions,
turn lifecycle, approvals), while ACP is the agent-side protocol coding agents
speak with their clients. MCP is orthogonal — it's tool discovery and
invocation, not sessions.

## Next Steps

- [Build an agent to serve over a protocol](/ask-docs/core/agent)
- [Expose an ask-rb agent as an app-server](/ask-docs/core/app-server)
- [MCP client and server](/ask-docs/core/mcp)
- [The full gem index](/ask-docs/reference/gems)
