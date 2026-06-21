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


```ruby
gem "ask-llm-providers"
```

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
