---
layout: default
title: MCP Client
parent: Core Components
nav_order: 6
---


# ask-mcp

**Model Context Protocol (MCP) client and server for Ruby.** Connect to MCP
servers via stdio, SSE, or Streamable HTTP transports. Discover tools,
resources, and prompts. Or run the other way: expose your own tools as an MCP
server over stdio. Supports the full MCP protocol with OAuth 2.1
authentication.

MCP is the industry standard for LLM tool discovery — the same protocol used by
Claude Code, Codex, Cursor, GitHub Copilot, and many other AI clients.

```ruby
gem "ask-mcp"
```

```ruby
gem "ask-mcp"
```

## Quick Start

```ruby
require "ask/mcp"

# Connect to a local MCP server via stdio
client = Ask::MCP.from_stdio("npx", ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"])
client.start

# List available tools
client.tools.each { |name, tool| puts "#{name}: #{tool.description}" }

# Call a tool
result = client.call_tool("read_file", path: "/tmp/test.txt")
puts result

# Clean up
client.stop
```

## Transports

ask-mcp supports three transports:

| Transport | Class | When to Use |
|---|---|---|
| stdio | `Ask::MCP::Transport::Stdio` | Local processes (CLI tools, local MCP servers) |
| SSE | `Ask::MCP::Transport::SSE` | Remote servers with Server-Sent Events |
| Streamable HTTP | `Ask::MCP::Transport::StreamableHTTP` | Remote HTTP servers |

```ruby
# Factory methods for common cases
Ask::MCP.from_stdio("npx", ["-y", "@modelcontextprotocol/server-github"])
Ask::MCP.from_sse("https://mcp.example.com/sse")
Ask::MCP.from_http("https://mcp.example.com/mcp")

# Or create explicitly
transport = Ask::MCP::Transport::Stdio.new("ruby", ["server.rb"])
client = Ask::MCP::Client.new(transport, timeout: 30)
```

## Client API

```ruby
client = Ask::MCP.from_stdio("ruby", ["server.rb"])
client.start

# Discover capabilities
client.tools       # => Hash of name → Ask::MCP::Tool
client.resources   # => Hash of uri → Ask::MCP::Resource
client.prompts     # => Hash of name → Ask::MCP::Prompt

# Call tools and read resources
client.call_tool("tool_name", arg1: "value")
client.read_resource("file:///path/to/file")
client.get_prompt("prompt_name", name: "World")

client.stop
```

### Result Caching

Tools, resources, and prompts are cached after the first request.
Calling the method again returns the same cached Hash.
To bypass caching, pass `no_cache: true` to the client constructor.

Cache is automatically invalidated when the server sends
`notifications/tools/list_changed` (or resources/prompts).

## Input Validation

ask-mcp validates tool call arguments against JSON Schema when enabled:

```ruby
client = Ask::MCP::Client.new(transport, validate: true)
client.start

# Raises Ask::MCP::Validator::ValidationError if arguments are invalid
client.call_tool("echo", message: "hello")     # OK
client.call_tool("echo", nonexistent: true)    # Raises error
```

Or validate directly:

```ruby
Ask::MCP.validate!(input_schema, arguments)
validator = Ask::MCP::Validator.new(schema)
validator.valid?(args)   # => true/false
validator.validate!(args) # => true or raises ValidationError
```

## Authentication

ask-mcp provides two authentication classes:

**Token-based auth:**
```ruby
token = Ask::MCP::Auth::Token.new("my-token")
headers = token.apply({})  # => { "Authorization" => "Bearer my-token" }
```

**OAuth 2.1 (a machine credential):**
```ruby
oauth = Ask::MCP::Auth::OAuth.new(
  client_id: "my-client",
  client_secret: "my-secret",
  token_url: "https://auth.example.com/token"
)
oauth.authenticate!
headers = oauth.apply({})
```

**Browser OAuth — `Ask::MCP::Auth::Connect`:**

For servers a *person* signs into, `Connect` walks the chain MCP defines and hands
your host two steps to run in a browser — it keeps no state of its own, so the
host carries the `state` and the PKCE verifier between them.

<!-- docs-example: not-verified -->
```ruby
flow = Ask::MCP::Auth::Connect.new(endpoint: "https://mcp.example.com/mcp")

# 1. Send the browser here, and keep the verifier until the callback
outcome = flow.authorization_url(
  redirect_uri: "https://app.example.com/callback", state: state
)
# => { url: "https://auth.example.com/authorize?...", code_verifier: "..." }

# 2. Redeem the code the server redirected back with
tokens = flow.exchange(
  code: params[:code],
  verifier: outcome[:code_verifier],
  redirect_uri: "https://app.example.com/callback"
)
# => { access_token:, refresh_token:, expires_at:, scope: }

# Later, without a browser
tokens = flow.refresh(refresh_token: stored_refresh_token)
```

How it finds the door: the resource server's
`/.well-known/oauth-protected-resource` names its authorization servers
(RFC 9728), their metadata names the endpoints (RFC 8414 or OIDC discovery), and
when the server allows dynamic client registration the client is registered on
the spot — `flow.registered_client` is exposed so you can persist it rather than
asking twice. PKCE (S256) is always used, the scope comes from the server's own
advertisement, and the HTTP client is injectable (`http:`) for hosts that want
their own. Errors are `Ask::MCP::Auth::Connect::Error`.

For details, see the [Auth Setup Guide](https://github.com/ask-rb/ask-mcp/blob/master/docs/auth-setup.md).

## With ask-agent

Convert MCP tools to Ask::Tool instances for use with Ask::Agent:

```ruby
client = Ask::MCP.from_stdio("npx", ["-y", "@modelcontextprotocol/server-github"])
client.start

# Via Tool#to_ask_tool
client.tools.each { |name, tool| agent.register_tool(tool.to_ask_tool) }

# Via AskTool adapter
wrapped = Ask::MCP::Adapters::AskTool.wrap(client.tools)
wrapped.each { |name, adapter| agent.register_tool(adapter.to_ask_tool) }
```

### Execute MCP tools through the runtime

If you are building your own executor pipeline, use
`Ask::MCP::RuntimeExecutor`. It preserves the MCP tool name and arguments,
normalizes MCP content and errors into `Ask::Runtime::ToolResult`, and emits
the standard runtime lifecycle events.

<!-- docs-example: not-verified -->
```ruby
require "ask/mcp"

client = Ask::MCP.from_stdio("my-mcp-server")
client.start
executor = Ask::MCP::RuntimeExecutor.new(client)
call = Ask::Runtime::ToolCall.new(
  tool_name: "search",
  input: { query: "Ruby" },
  session_id: "session_42",
  turn: 1
)

result = executor.execute(call)
result.success? # => true when the MCP server returns a normal result
```

Use this path when your host owns the execution loop. If you are building an
Ask agent, register the MCP tools with `Ask::Agent` and let its loop manage the
conversation; the same runtime contract is available underneath.

## Expose your own tools as a server

Ask::MCP also runs the other way. `Ask::MCP::Adapters::ToolServer` wraps any
collection of duck-typed tools (name, description, call) into MCP definitions,
and `Server.start_stdio` serves them over stdio to any MCP client:

```ruby
require "ask/mcp"
require "ask-tools-shell"

Ask::MCP::Server.start_stdio(
  name: "my-tools",
  tools: Ask::Tools::Shell::TOOLS.map(&:new)
)
```

Any MCP client — Claude Code, Cursor, ZCode, your own `Ask::MCP::Client` — can
now discover and call those tools. This is exactly how
[ask-web-search-mcp](/ask-docs/core/web-search) and
[ask-rails-harness-mcp](/ask-docs/rails/mcp) are built.

## Next steps

- [Execution Runtime](/ask-docs/core/runtime) — understand calls, contexts,
  results, cancellation, and lifecycle events.
- [The Agent Loop](/ask-docs/core/agent) — let an Ask agent select MCP tools.
- [Sandbox Providers](/ask-docs/core/sandbox) — run local or remote commands
  through the same runtime seam.

## Architecture

```
ask-mcp/
├── lib/ask/mcp.rb                         # Entry point, factory methods
├── lib/ask/mcp/client.rb                  # MCP client
├── lib/ask/mcp/server.rb                  # MCP server (start_stdio)
├── lib/ask/mcp/tool.rb                    # Tool model
├── lib/ask/mcp/resource.rb                # Resource model
├── lib/ask/mcp/prompt.rb                  # Prompt model
├── lib/ask/mcp/validator.rb               # JSON Schema validator
├── lib/ask/mcp/native/messages.rb         # JSON-RPC message layer
├── lib/ask/mcp/transport/
│   ├── stdio.rb                           # stdio transport
│   ├── sse.rb                             # SSE transport
│   └── streamable_http.rb                 # Streamable HTTP transport
├── lib/ask/mcp/auth/
│   ├── oauth.rb                           # OAuth 2.1
│   └── token.rb                           # Token auth
└── lib/ask/mcp/adapters/
    ├── ask_tool.rb                        # MCP tool → Ask::Tool
    └── tool_server.rb                     # Ask tools → MCP server
```
