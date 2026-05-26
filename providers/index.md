---
layout: default
title: Providers
nav_order: 5
---

# Providers

One gem per provider. Each implements `Ask::Provider` and knows its own wire format, auth, and streaming.

## Available providers

| Gem | Provider |
|-----|----------|
| `ask-openai` | OpenAI, DeepSeek, OpenRouter, and all OpenAI-compatible APIs |
| `ask-anthropic` | Anthropic Claude (Messages API, thinking blocks, prompt caching) |
| `ask-google` | Google Gemini + Vertex AI |
| `ask-ollama` | Local models via Ollama |

## Usage

```ruby
# OpenAI
provider = Ask::Provider::OpenAI.new(api_key: "sk-...")
provider.chat(conversation, tools:, model: "gpt-4o") { |chunk| ... }

# OpenAI-compatible (OpenRouter, LiteLLM, etc.)
Ask::Provider::OpenAI.new(
  api_key: "...",
  base_url: "https://openrouter.ai/api/v1"
)

# Anthropic
provider = Ask::Provider::Anthropic.new(api_key: "sk-ant-...")
provider.chat(conversation, tools:, thinking: { effort: :high }) { |chunk| ... }
```
