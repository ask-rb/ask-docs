---
layout: default
title: Foundation (ask-core)
parent: Core Components
nav_order: 2
---

# ask-core

**The foundation gem.** Zero dependencies. Every `ask-rb` app depends on this.

```ruby
gem "ask-core"
```

## What it provides

### Conversation

The core data structure — an ordered list of messages that can be serialized for any provider API.

```ruby
conversation = Ask::Conversation.new
conversation.add_message(:system, "You are a helpful assistant")
conversation.add_message(:user, "What's the weather in Paris?")
conversation.add_message(:assistant, tool_calls: [
  { id: "call_1", name: "get_weather", arguments: { city: "Paris" } }
])
conversation.to_a  # => array of hashes ready for API call
```

### Streaming

Receive responses incrementally without mutating state.

```ruby
stream = Ask::Stream.new
stream.each { |chunk| print chunk.content }
stream.transcript  # full accumulated response
```

### Provider interface

A base class that all provider gems implement.

```ruby
class MyProvider < Ask::Provider
  def chat(conversation, tools: [], model: nil, &stream_block)
    # Returns Ask::Response or calls stream_block with Ask::Chunk
  end
end
```

### Auth helpers

```ruby
Ask::Auth.from_env("OPENAI_API_KEY")          # env var
Ask::Auth::OAuth.new(client_id: "...")         # PKCE flow
Ask::Auth::CredentialStore.new(path: "...")    # file-backed with 0600
```

### Role mapping

```ruby
Ask::RoleMap.normalize("developer")  # => "system"
Ask::RoleMap.normalize("ai")         # => "assistant"
```

### Model Catalog

A process-wide singleton registry of known LLM models. Each entry is an immutable `Ask::ModelInfo` value object.

```ruby
# Find a model by ID (provider preference resolves ambiguity)
model = Ask::ModelCatalog.find("gpt-4o")
model.provider         # => "openai"
model.context_window   # => 128000
model.max_output_tokens # => 16384
model.supports?(:vision) # => true
model.capabilities     # => ["function_calling", "structured_output", "vision"]

# Filter by capability
Ask::ModelCatalog.chat_models          # models that support chat
Ask::ModelCatalog.embedding_models     # models that support embeddings
Ask::ModelCatalog.audio_models         # models with audio output
Ask::ModelCatalog.image_models         # models with image output

# Filter by metadata
Ask::ModelCatalog.by_provider("openai")
Ask::ModelCatalog.by_family("gpt")

# Refresh from models.dev API
Ask::ModelCatalog.refresh!
```

Models are loaded into the catalog by `Ask::LLM::Catalog.load!` (from ask-llm-providers) or registered individually:

```ruby
model = Ask::ModelInfo.new(
  id: "my-model",
  provider: "local",
  context_window: 4096,
  max_output_tokens: 1024,
  capabilities: ["chat"]
)
Ask::ModelCatalog.instance.register(model)
```

### ModelInfo

Immutable value object for model metadata.

| Attribute | Type | Description |
|---|---|---|
| `id` | String | Model identifier (e.g. `"gpt-4o"`) |
| `name` | String | Human-readable name |
| `provider` | String | Provider slug (e.g. `"openai"`) |
| `family` | String, nil | Model family (e.g. `"gpt"`, `"claude"`) |
| `capabilities` | Array<String> | Capability flags |
| `context_window` | Integer, nil | Max context window in tokens |
| `max_output_tokens` | Integer, nil | Max output tokens |
| `modalities` | Hash | Input/output modality lists |
| `pricing` | Hash | Cost per token |
| `knowledge_cutoff` | Date, nil | Training data cutoff |
| `created_at` | Date, nil | Release date |

### Error Types

Structured errors with actionable metadata. `RateLimitError` carries category, type, and retry-after for intelligent handling:

```ruby
rescue Ask::RateLimitError => e
  e.category        # => :vendor (upstream provider) or :local (ask-rb)
  e.rate_limit_type # => :requests, :tokens, :concurrent, or :budget
  e.retry_after     # => seconds to wait before retrying (from provider headers)
  
  if e.category == :vendor && e.retry_after
    sleep e.retry_after
    retry
  end
end
```

| Error | When |
|---|---|
| `Ask::RateLimitError` | 429 — carries `category`, `rate_limit_type`, `retry_after` |
| `Ask::Unauthorized` | 401/403 — API key missing or invalid |
| `Ask::ServerError` | 5xx — provider outage |
| `Ask::ServiceUnavailable` | 503 — temporary downtime |
| `Ask::ContextLengthExceeded` | Context window exceeded |
| `Ask::ProviderError` | Other provider API errors (carries `status_code`, `response_body`) |

### CostCalculator

`Ask::LLM::CostCalculator` computes API costs from model pricing data. Supports text and audio tokens, cache read/write, reasoning tokens, and batch tier pricing:

```ruby
cost = Ask::LLM::CostCalculator.calculate(model,
  input_tokens: 1000, output_tokens: 500,
  cache_read_tokens: 2000, reasoning_tokens: 200,
  tier: :batch)

Ask::LLM::CostCalculator.per_million(model)
# => { input: 2.5, output: 10.0, cache_read: 1.25, ... }
```

### Model pricing data

The gem ships **406 models across 12 providers** with pricing data sourced from models.dev and OpenRouter. Run `rake models:update` to refresh before releasing.

## Exports

`Conversation`, `Stream`, `Chunk`, `Response`, `Provider`, `ToolDef`, `ToolCall`, `Auth`, `Auth::OAuth`,
`Auth::CredentialStore`, `RoleMap`, `Error` classes.
