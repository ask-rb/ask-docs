---
layout: default
title: ask-core
nav_order: 2
---

# ask-core

**The foundation gem.** Zero runtime dependencies. Every `ask-rb` provider gem depends on this.

```ruby
gem "ask-core"
```

## Components

| Component | Purpose |
|---|---|
| `Ask::Provider` | Abstract base class for all LLM providers |
| `Ask::Conversation` | Message container with role normalization |
| `Ask::Stream` / `Ask::Chunk` | Streaming primitives |
| `Ask::ModelCatalog` | Model name to provider resolution |
| `Ask::ToolDef` | Immutable tool metadata struct |
| `Ask::Result` | Standardized tool return value |
| `Ask::Error` | Structured error types (18 classes) |

## Service Context Gems

| Gem | Purpose |
|---|---|
| [ask-auth](/core/ask-auth) | Credential resolution chain |
| [ask-github](/core/ask-github) | GitHub API — issues, PRs, repos |
| [ask-sentry](/core/ask-sentry) | Sentry — error tracking via the Sentry API |
| [ask-honeybadger](/core/ask-honeybadger) | Honeybadger — error tracking via the Honeybadger API |
| [ask-linear](/core/ask-linear) | Linear — issue tracking |
| [ask-notion](/core/ask-notion) | Notion — pages and databases |
| [ask-slack](/core/ask-slack) | Slack — messaging and channels |

## Usage

### Provider

Provider gems subclass `Ask::Provider` and implement `#chat`, `#embed`, `#list_models`, and `#api_base`.

```ruby
class MyProvider < Ask::Provider
  def api_base = "https://api.example.com/v1"
  def headers = { "Authorization" => "Bearer #{@config.api_key}" }

  def chat(messages, model:, tools: nil, temperature: nil, stream: nil, schema: nil, **params, &block)
    # Return an Ask::Message or yield Ask::Chunks to the block when streaming
  end

  def embed(text, model:)
    [0.1, 0.2, 0.3]  # embedding vector
  end

  def list_models
    [Ask::ModelInfo.new(id: "my-model", provider: "my_provider")]
  end
end

Ask::Provider.register(:my_provider, MyProvider)
Ask::Provider.resolve(:my_provider)  # => MyProvider
```

### Conversation

Build and manipulate conversations with role-normalized messages.

```ruby
conv = Ask::Conversation.new

# Convenience methods
conv.system("You are a helpful assistant.")
conv.user("What's the weather in Tokyo?")
conv.assistant("Let me check...", tool_calls: [
  { name: "get_weather", arguments: { location: "Tokyo" } }
])
conv.tool_result("72°F, sunny", tool_call_id: "call_123")

# Iteration
conv.each { |msg| puts "#{msg.role}: #{msg.content}" }

# Filtering
conv.user_messages
conv.system_messages
conv.assistant_messages
conv.tool_messages

# Serialization
conv.to_a  # => [{ role: :user, content: "..." }, ...]
```

### Messages

```ruby
msg = Ask::Message.new(role: :user, content: "Hello")
msg.user?        # => true
msg.assistant?   # => false
msg.tool_call?   # => false
msg.tool_result? # => false

# Tool call message
msg = Ask::Message.new(role: :assistant, tool_calls: [{ name: "f", arguments: {} }])
msg.tool_call?   # => true

# Tool result message
msg = Ask::Message.new(role: :tool, content: "result", tool_call_id: "call_1")
msg.tool_result? # => true
```

Valid roles: `:system`, `:user`, `:assistant`, `:tool`.

### Streaming

```ruby
stream = Ask::Stream.new { |chunk| print chunk.content }

# Add chunks as they arrive from the provider
stream.add(Ask::Chunk.new(content: "Hello "))
stream.add(Ask::Chunk.new(content: "World"))
stream.finish!

stream.accumulated_text  # => "Hello World"
stream.to_s              # => "Hello World"
stream.accumulated_usage # => { input_tokens: 10, output_tokens: 20 }
stream.length            # => 2
```

### Model Catalog

```ruby
catalog = Ask::ModelCatalog.new([
  Ask::ModelInfo.new(id: "gpt-4o", provider: "openai", capabilities: ["function_calling", "vision"]),
  Ask::ModelInfo.new(id: "claude-sonnet-4", provider: "anthropic")
])

catalog.find("gpt-4o")
catalog.find("gpt-4o", "openai")
catalog.chat_models
catalog.embedding_models
catalog.by_provider("openai")

# Singleton instance
Ask::ModelCatalog.instance
Ask::ModelCatalog.find("gpt-4o")
```

### Tool Definitions

```ruby
tool = Ask::ToolDef.new(
  name: "get_weather",
  description: "Get current weather for a location",
  parameters: {
    type: "object",
    properties: {
      location: { type: "string", description: "City name" }
    },
    required: ["location"]
  }
)

tool.name         # => "get_weather"
tool.frozen?      # => true
tool.to_provider_format { |t| { type: "function", function: t.to_h } }
```

### Tool Results

```ruby
Ask::Result.success("Data processed")
Ask::Result.failure("API returned 500", error: "Timeout")
Ask::Result.aborted("Cancelled")
Ask::Result.blocked("Permission denied")

result = Ask::Result.success("OK")
result.success?  # => true
result.error?    # => false
result.to_h      # => { content: "OK", status: :success, metadata: {} }
```

### Error Handling

```ruby
begin
  Ask::Provider.resolve(:unknown)
rescue Ask::UnknownProvider => e
  e.message  # => "Unknown provider: :unknown..."
end

begin
  Ask::ModelCatalog.find("nonexistent")
rescue Ask::ModelNotFound => e
  e.message  # => "Unknown model: 'nonexistent'..."
end
```

## Implementation

- **Zero runtime dependencies** — uses only Ruby stdlib (`json`, `net/http`, `date`, `time`)
- **Immutable value objects** — `Message`, `ToolDef`, `Result`, `Chunk`, `ModelInfo` are all frozen after construction
- **Thread-safe registry** — `Ask::Provider.providers` guarded by `Mutex`
- **Extracted parser** — `Ask::ModelsDevParser` can be unit tested independently of HTTP

## Exports

`Provider`, `Conversation`, `Message`, `Stream`, `Chunk`, `ModelCatalog`, `ModelInfo`, `ModelsDevParser`,
`ToolDef`, `Result`, `Error`, `ConfigurationError`, `UnknownProvider`, `ModelNotFound`,
`InvalidRole`, `InvalidToolDefinition`, `ProviderError`, `ContextLengthExceeded`,
`RateLimitError`, `Unauthorized`, `ServerError`, `ServiceUnavailable`, `ConversationError`,
`StreamError`, `UnsupportedFeature`, `MissingCredential`, `InvalidCredential`.
