---
layout: default
title: LLM Providers
parent: Core Components
nav_order: 1
---

# LLM Providers

**All LLM providers for the ask-rb ecosystem.** A single gem containing every provider — each with its own wire format, auth, and capabilities, all implementing the same `Ask::Provider` contract.

```ruby
gem "ask-llm-providers"
```

## Quick Start

```ruby
require "ask-llm-providers"

provider = Ask::Providers::OpenAI.new(api_key: "sk-...")
response = provider.chat(
  [{ role: "user", content: "Hello!" }],
  model: "gpt-4o"
)
puts response.content
```

## Provider Transformation Contract

Every provider implements the `Ask::LLM::ProviderConfig` interface, which separates wire-format concerns into five public methods:

```ruby
provider.build_request(messages, model:, tools: nil, temperature: nil, stream: nil, schema: nil)
  # => Hash (provider-native request payload)

provider.parse_response(body, model)
  # => Ask::Message

provider.parse_stream(raw, stream, model, &block)
  # => yields Ask::Chunks

provider.format_tools(tools)
  # => Array (provider-native tool format)

provider.format_message(msg)
  # => Hash (provider-native message format)
```

This makes each wire-format concern testable in isolation and adding a new provider mechanical — implement five methods and the provider works. Inspired by LiteLLM's `BaseConfig` pattern.

## Canonical Providers

These providers have distinct wire formats. Each is a dedicated class with its own serialization, streaming, and auth.

| Provider | Class | Capabilities | Auth |
|---|---|---|---|
| OpenAI | `Ask::Providers::OpenAI` | Chat, streaming, tools, vision, embeddings, image gen, transcription | `OPENAI_API_KEY` |
| Anthropic | `Ask::Providers::Anthropic` | Chat, streaming, tools, vision, thinking, prompt caching | `ANTHROPIC_API_KEY` |
| Google Gemini | `Ask::Providers::Google` | Chat, streaming, tools, vision, embeddings, file upload | `GEMINI_API_KEY` |
| Amazon Bedrock | `Ask::Providers::Bedrock` | Chat, streaming, tools, vision | AWS credentials chain |
| Ollama | `Ask::Providers::Ollama` | Chat, streaming, tools, embeddings (local) | None needed |
| Mistral AI | `Ask::Providers::Mistral` | Chat, streaming, tools, structured output, embeddings | `MISTRAL_API_KEY` |
| Cloudflare | `Ask::Providers::Cloudflare` | Chat, streaming, vision | `CLOUDFLARE_API_KEY` + Account ID |

## OpenAI-Compatible Providers

These share OpenAI's wire format. Each is configured via a registry entry — no subclass, no new file. Adding a new provider is one line in `lib/ask/llm/openai_compatible.rb`.

| Provider | Env Var | Capabilities |
|---|---|---|
| DeepSeek | `DEEPSEEK_API_KEY` | Chat, streaming, tools, thinking |
| OpenRouter | `OPENROUTER_API_KEY` | Chat, streaming, tools, vision, thinking, structured output |
| Groq | `GROQ_API_KEY` | Chat, streaming, tools, vision |
| Together | `TOGETHER_API_KEY` | Chat, streaming, tools |
| Fireworks | `FIREWORKS_API_KEY` | Chat, streaming, tools |
| Cerebras | `CEREBRAS_API_KEY` | Chat, streaming, tools |
| xAI | `XAI_API_KEY` | Chat, streaming, tools, vision, thinking |
| Perplexity | `PERPLEXITY_API_KEY` | Chat, streaming |
| Moonshot | `MOONSHOT_API_KEY` | Chat, streaming |
| DeepInfra | `DEEPINFRA_API_KEY` | Chat, streaming, tools |
| Anyscale | `ANYSCALE_API_KEY` | Chat, streaming, tools |
| SambaNova | `SAMBANOVA_API_KEY` | Chat, streaming, tools |
| Nebius | `NEBIUS_API_KEY` | Chat, streaming, tools |
| Nvidia NIM | `NVIDIA_NIM_API_KEY` | Chat, streaming, tools |
| Friendli | `FRIENDLI_API_KEY` | Chat, streaming, tools |
| Hyperbolic | `HYPERBOLIC_API_KEY` | Chat, streaming, tools |
| Novita | `NOVITA_API_KEY` | Chat, streaming, tools |
| Nscale | `NSCALE_API_KEY` | Chat, streaming, tools |
| Featherless | `FEATHERLESS_API_KEY` | Chat, streaming, tools |
| AI/ML API | `AIML_API_KEY` | Chat, streaming, tools |
| AI21 | `AI21_API_KEY` | Chat, streaming, tools |
| Meta (Llama) | `LLAMA_API_KEY` | Chat, streaming, tools |
| GitHub Models | `GITHUB_API_KEY` | Chat, streaming, tools, vision |
| OpenCode | `OPENCODE_API_KEY` | Chat, streaming, tools |
| OpenCode Go | `OPENCODE_API_KEY` or `OPENCODE_GO_API_KEY` | Chat, streaming, tools |
| Mimo | `MIMO_API_KEY` | Chat, streaming |

## Using a Model Through a Different Provider

A model is registered under a specific provider in the catalog (e.g., `deepseek-v4-flash` under the `deepseek` provider). But you may want to use it through a different provider that serves the same model — for instance, `deepseek-v4-flash` served by `opencode_go`.

Pass the `provider:` parameter to override which provider serves the model:

```ruby
session = Ask::Agent::Session.new(
  model: "deepseek-v4-flash",
  provider: :opencode_go,  # use opencode_go instead of the default deepseek provider
  tools: [...]
)
```

Or when using `Ask::Agent::Chat` directly:

```ruby
chat = Ask::Agent::Chat.new(
  model: "deepseek-v4-flash",
  provider: :opencode_go
)
```

This works because the agent checks `provider:` first, then falls back to the catalog's provider. It also means you can use any OpenAI-compatible provider with any model name the provider supports, without adding model entries to the catalog.

The `provider:` parameter is available on both `Ask::Agent::Session.new` and `Ask::Agent::Chat.new` — it passes through to the underlying provider resolution.

## Provider Registration

All providers auto-register with `Ask::Provider` on gem load:

```ruby
Ask::Provider.providers  # => { openai: OpenAI, anthropic: Anthropic, deepseek: ..., groq: ..., ... }
Ask::Provider.resolve(:openai)  # => Ask::Providers::OpenAI
Ask::Provider.resolve(:deepseek)  # => resolves to the OpenAICompatible subclass for DeepSeek
```

### Adding a new OpenAI-compatible provider

Add one entry to the registry — no new file, no subclass:

```ruby
# lib/ask/llm/openai_compatible.rb
OPENAI_COMPATIBLE = {
  groq: { api_base: "https://api.groq.com/openai/v1", api_key_env: "GROQ_API_KEY",
          capabilities: { chat: true, streaming: true, tool_calls: true, vision: true } },
  # ... add yours here
}
```

Special quirks are handled declaratively:

```ruby
deepseek: { api_base: "https://api.deepseek.com", api_key_env: "DEEPSEEK_API_KEY",
            reasoning_content: true },  # injects reasoning_content for tool call messages

openrouter: { api_base: "https://openrouter.ai/api/v1", api_key_env: "OPENROUTER_API_KEY",
              extra_headers: { "HTTP-Referer" => "...", "X-Title" => "ask-rb" } },

opencode_go: { api_base: "https://opencode.ai/zen/go/v1", api_key_env: "OPENCODE_API_KEY" },
             # Also accepts OPENCODE_GO_API_KEY via slug convention
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

## Model Catalog

The gem automatically populates `Ask::ModelCatalog` when loaded:

```ruby
Ask::ModelCatalog.find("gpt-4o")
Ask::ModelCatalog.find("claude-sonnet-4-6")
```

Models are defined in JSON files under `lib/ask/llm/models/` with pricing, context windows, and capabilities. Short names are resolved via aliases:

```ruby
Ask::LLM::Aliases.resolve("claude-sonnet-4")
# => "claude-sonnet-4-6"
```

## Development

```bash
git clone https://github.com/ask-rb/ask-llm-providers
cd ask-llm-providers
bundle exec rake test
```
