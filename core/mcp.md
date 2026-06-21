---
layout: default
title: MCP Client
parent: Core Components
nav_order: 6
---


# ask-mcp

**Model Context Protocol (MCP) client for Ruby.** Connect to MCP servers via
stdio, SSE, or Streamable HTTP transports. Discover tools, resources, and
prompts. Supports the full MCP protocol with OAuth 2.1 authentication.

MCP is the industry standard for LLM tool discovery — the same protocol used by
Claude Code, Codex, Cursor, and GitHub Copilot.

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

**OAuth 2.1:**
```ruby
oauth = Ask::MCP::Auth::OAuth.new(
  client_id: "my-client",
  client_secret: "my-secret",
  token_url: "https://auth.example.com/token"
)
oauth.authenticate!
headers = oauth.apply({})
```

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

## Architecture

```
ask-mcp/
├── lib/ask/mcp.rb                         # Entry point, factory methods
├── lib/ask/mcp/client.rb                  # MCP client
├── lib/ask/mcp/server.rb                  # MCP server representation
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
    └── ask_tool.rb                        # → Ask::Tool adapter
```
