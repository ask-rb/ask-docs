---
layout: default
title: LLM Providers
parent: Core Components
nav_order: 1
---

# LLM Providers

**All LLM providers for the ask-rb ecosystem.** One gem containing OpenAI, Anthropic, Google Gemini, Amazon Bedrock, Ollama, Mistral AI, and Cloudflare Workers AI.

```ruby
gem "ask-llm-providers"
```

## Model Catalog

The gem ships a model catalog that loads known model data into `Ask::ModelCatalog` on startup. Call `load!` once during application boot:

```ruby
require "ask-llm-providers"
Ask::LLM::Catalog.load!

# Models are now available through Ask::ModelCatalog
Ask::ModelCatalog.find("gpt-4o")
Ask::ModelCatalog.find("claude-sonnet-4-6")
```

### Bundled model definitions

Models are defined in JSON files under `lib/ask/llm/models/`. Each file represents a provider's models:

```json
{
  "id": "gpt-4o",
  "name": "GPT-4o",
  "provider": "openai",
  "family": "gpt",
  "context_window": 128000,
  "max_output_tokens": 16384,
  "capabilities": ["function_calling", "structured_output", "vision"],
  "modalities": {
    "input": ["text", "image"],
    "output": ["text"]
  },
  "pricing": {
    "input_per_million": 2.5,
    "output_per_million": 10.0
  }
}
```

### Alias resolution

Short or familiar names are resolved to canonical model IDs automatically:

```ruby
Ask::LLM::Aliases.resolve("claude-sonnet-4")
# => "claude-sonnet-4-6"

# Aliases are also registered in the catalog, so ModelCatalog.find works directly:
Ask::ModelCatalog.find("deepseek-v4")
# => returns the ModelInfo for deepseek-v4-flash
```

### User overrides

Place a JSON array at `~/.ask-llm-providers/models.json` to override bundled model data:

```json
[
  {
    "id": "gpt-4o",
    "pricing": {
      "input_per_million": 1.0,
      "output_per_million": 5.0
    }
  }
]
```

Overrides merge by `(id, provider)` key — user values win on conflict.

### API refresh

To fetch the latest model lists from provider APIs:

```ruby
Ask::LLM::Catalog.refresh!
```

This calls `list_models()` on every configured provider and adds any unknown models with minimal metadata.

## Supported Providers

| Provider | Class | Capabilities | Auth |
|---|---|---|---|
| OpenAI | `Ask::Providers::OpenAI` | Chat, streaming, tools, vision, embeddings, image gen, transcription | `OPENAI_API_KEY` |
| Anthropic | `Ask::Providers::Anthropic` | Chat, streaming, tools, vision, thinking, prompt caching | `ANTHROPIC_API_KEY` |
| Google Gemini | `Ask::Providers::Google` | Chat, streaming, tools, vision, embeddings, file upload | `GEMINI_API_KEY` |
| Amazon Bedrock | `Ask::Providers::Bedrock` | Chat, streaming, tools, vision | AWS credentials chain |
| Ollama | `Ask::Providers::Ollama` | Chat, streaming, tools, embeddings (local) | None needed |
| Mistral AI | `Ask::Providers::Mistral` | Chat, streaming, tools, structured output, embeddings | `MISTRAL_API_KEY` |
| Cloudflare | `Ask::Providers::Cloudflare` | Chat, streaming, vision | `CLOUDFLARE_API_KEY` + Account ID |

## Quick Start

```ruby
require "ask-llm-providers"

# Use a provider directly
provider = Ask::Providers::OpenAI.new(api_key: "sk-...")
response = provider.chat(
  [{ role: "user", content: "Hello!" }],
  model: "gpt-4o"
)
puts response.content
```

## Streaming

```ruby
stream = provider.chat(
  [{ role: "user", content: "Tell me a story" }],
  model: "gpt-4o",
  stream: true
) do |chunk|
  print chunk.content
end
```

## Tool Calls

```ruby
tools = [{
  name: "get_weather",
  description: "Get weather for a location",
  parameters: {
    type: "object",
    properties: { location: { type: "string" } },
    required: ["location"]
  }
}]

response = provider.chat(
  [{ role: "user", content: "What's the weather in NYC?" }],
  model: "gpt-4o",
  tools: tools
)
# response.tool_call? => true
# response.tool_calls => [{ name: "get_weather", arguments: "..." }]
```

## Provider Registration

All providers auto-register with `Ask::Provider` on gem load:

```ruby
Ask::Provider.providers  # => { openai: OpenAI, anthropic: Anthropic, ... }
Ask::Provider.resolve(:openai)  # => Ask::Providers::OpenAI
```

## Capabilities Introspection

```ruby
Ask::Providers::OpenAI.capabilities
# => { chat: true, streaming: true, tool_calls: true, vision: true, ... }

Ask::Providers::Ollama.local?  # => true
Ask::Providers::OpenAI.local?  # => false
```

## Error Handling

Provider errors map to structured `Ask::Error` types:

```ruby
Ask::RateLimitError       # 429
Ask::Unauthorized         # 401/403
Ask::ServerError          # 500
Ask::ServiceUnavailable   # 503
Ask::ContextLengthExceeded # context_length_exceeded
Ask::ProviderError        # other errors
```

## Development

```bash
git clone https://github.com/ask-rb/ask-llm-providers
cd ask-llm-providers
bundle exec rake test
```
