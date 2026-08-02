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

### Role mapping

Message roles are normalized on construction. `"user"`, `:user`, and any
string form become the canonical symbol; unknown roles raise `InvalidRole`.

```ruby
Ask::Message.new(role: "user", content: "hi").user?  # => true
Ask::Message.new(role: :bogus, content: "hi")        # raises Ask::InvalidRole
```

The valid roles are `:system`, `:user`, `:assistant`, and `:tool`.

### Credential resolution

Credentials are resolved by the `ask-auth` gem, not by ask-core. `Ask::Auth.resolve(:openai_api_key)` walks env vars, `~/.ask/credentials.yml`, Rails credentials, a database-backed store, and OAuth — see [Credential Resolution](/ask-docs/core/auth).

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

### Provider Override

When using the catalog through `ask-agent`, you can override which provider serves a model by passing `provider:` to `Ask::Agent::Session` or `Ask::Agent::Chat`:

```ruby
# deepseek-v4-flash is cataloged under the "deepseek" provider,
# but can be served through a different compatible provider:
session = Ask::Agent::Session.new(
  model: "deepseek-v4-flash",
  provider: :opencode_go,
  tools: [...]
)
```

This bypasses the catalog's `provider` field and uses the specified provider instead. Useful when a model is available through multiple providers (e.g., self-hosted vs API).

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

### Document

`Ask::Document` is a frozen value object for text content with metadata. It flows through every stage of a RAG pipeline — loaded from files, split into chunks, embedded and stored, and returned by retrieval queries.

```ruby
doc = Ask::Document.new(
  content: "Ruby was created by Matz in 1995.",
  metadata: { source: "history.pdf", page: 3 }
)
doc.content   # => "Ruby was created by Matz in 1995."
doc.metadata  # => { source: "history.pdf", page: 3 }
doc.id        # => nil (optional)
doc.to_h      # => { content: "...", metadata: { source: "history.pdf", page: 3 } }
```

Two documents are equal when their content and metadata match. The `id` field is ignored for equality comparisons.

### Content (Multi-Modal)

`Ask::Content` provides typed value objects for multi-modal message content. Messages can carry images, audio, video, and files alongside text.

```ruby
# Text
Ask::Content::Text.new("What's in this image?")

# Image from URL
Ask::Content::Image.new(url: "https://example.com/photo.jpg", mime_type: "image/jpeg")

# Image from base64 data
Ask::Content::Image.new(base64: "...base64...", mime_type: "image/png")

# Audio
Ask::Content::Audio.new(url: "https://example.com/audio.mp3", mime_type: "audio/mpeg")

# Video
Ask::Content::Video.new(url: "https://example.com/video.mp4", mime_type: "video/mp4")

# File (inline content)
Ask::Content::File.new(data: "file content", mime_type: "text/plain", filename: "notes.txt")
```

Use content blocks in messages:

```ruby
msg = Ask::Message.new(role: :user, content: [
  Ask::Content::Text.new("What's in this image?"),
  Ask::Content::Image.new(url: "https://example.com/photo.jpg", mime_type: "image/jpeg")
])

msg.multimodal?      # => true
msg.content_blocks   # => [Text("What's in this?"), Image(...)]
msg.content          # => "What's in this image?" (backward compatible)

# Or via conversation
conv.user([
  Ask::Content::Text.new("Describe this"),
  Ask::Content::Image.new(base64: "data", mime_type: "image/png")
])
```

Content blocks are frozen value objects with structural equality and `#to_h` serialization. Each provider (OpenAI, Anthropic, etc.) transforms them to its own wire format automatically.

### Cost calculation and pricing data

`Ask::LLM::CostCalculator` ships with `ask-llm-providers`, alongside the model
catalog data: 406 models across 12 providers with pricing from models.dev and
OpenRouter. Run `rake models:update` in the ask-llm-providers repo before a
release. See [LLM Providers](/ask-docs/core/providers).

## Exports

`Conversation`, `Message`, `Stream`, `Chunk`, `Provider`, `ModelCatalog`,
`ModelInfo`, `ToolDef`, `Result`, `Content` (`Text`, `Image`, `Audio`,
`Video`, `File`), `Document`, `ProviderTool`, `State::Adapter`, and the
`Ask::Error` hierarchy.
