---
layout: default
title: Custom Providers
parent: Extending
nav_order: 2
---

# Custom Providers

Build an LLM provider for any API. Providers are the bridge between the ask-rb ecosystem and LLM APIs — every provider implements the same interface.

## The Provider Contract

Subclass `Ask::Provider` and implement these methods:

| Method | Required | Returns |
|---|---|---|
| `chat(messages, model:, **params, &block)` | Yes | `Ask::Message` or yields `Ask::Chunk` |
| `embed(text, model:)` | No | Array of floats |
| `list_models` | No | Array of `Ask::ModelInfo` |
| `api_base` | Yes | String (the API base URL) |
| `headers` | Yes | Hash of HTTP headers |

## Example: Custom API Provider

```ruby
class MyCustomProvider < Ask::Provider
  def api_base = "https://api.myservice.com/v1"

  def headers
    { "Authorization" => "Bearer #{@config.api_key}" }
  end

  def chat(messages, model:, tools: nil, temperature: nil, stream: nil, schema: nil, **params, &block)
    body = {
      model: model,
      messages: messages,
      temperature: temperature,
      stream: stream
    }

    body[:tools] = tools if tools
    body[:response_format] = { type: "json_object" } if schema

    response = connection.post("/chat/completions") do |req|
      req.body = body
      req.options.on_data = block if stream
    end

    if stream
      # Streaming handles chunks in the on_data callback
      return
    end

    Ask::Message.new(
      role: :assistant,
      content: response.body["choices"][0]["message"]["content"]
    )
  end

  def embed(text, model:)
    response = connection.post("/embeddings") do |req|
      req.body = { model: model, input: text }
    end
    response.body["data"][0]["embedding"]
  end

  def list_models
    response = connection.get("/models")
    response.body["data"].map do |m|
      Ask::ModelInfo.new(id: m["id"], provider: "my_custom")
    end
  end
end
```

## Registration

```ruby
Ask::Provider.register(:my_custom, MyCustomProvider)

# Now resolvable
Ask::Provider.resolve(:my_custom)  # => MyCustomProvider
```

## Capabilities Declaration

Tell the ecosystem what your provider supports:

```ruby
class MyCustomProvider < Ask::Provider
  def self.capabilities
    {
      chat: true,
      streaming: true,
      tool_calls: true,
      vision: false,
      embeddings: true,
      image_generation: false,
      transcription: false
    }
  end
end
```

## Streaming Support

```ruby
def chat(messages, model:, stream: nil, **params, &block)
  if stream
    connection.post("/chat/completions") do |req|
      req.body = { model: model, messages: messages, stream: true }
      req.options.on_data = ->(chunk) do
        chunk_data = JSON.parse(chunk)
        if chunk_data["choices"]&.first&.dig("delta", "content")
          yield Ask::Chunk.new(content: chunk_data["choices"].first["delta"]["content"])
        end
      end
    end
  else
    # Non-streaming path
  end
end
```

## Tool Calling

In your `chat` method, handle tool calls from the API response:

```ruby
def chat(messages, model:, tools: nil, **params)
  body = { model: model, messages: messages }
  body[:tools] = tools.map { |t| { type: "function", function: t } } if tools

  response = connection.post("/chat/completions", body)

  response_body = response.body
  choice = response_body["choices"][0]["message"]

  if choice["tool_calls"]
    # Return a message with tool calls
    Ask::Message.new(
      role: :assistant,
      tool_calls: choice["tool_calls"].map do |tc|
        { id: tc["id"], name: tc["function"]["name"], arguments: tc["function"]["arguments"] }
      end
    )
  else
    Ask::Message.new(role: :assistant, content: choice["content"])
  end
end
```

## Error Mapping

Map API errors to ask-rb's structured error types:

```ruby
rescue Faraday::TooManyRequestsError => e
  raise Ask::RateLimitError, "Rate limited by MyService"
rescue Faraday::UnauthorizedError => e
  raise Ask::Unauthorized, "Invalid API key for MyService"
rescue Faraday::TimeoutError => e
  raise Ask::ProviderError, "MyService request timed out"
```

## Testing

```ruby
class MyCustomProviderTest < Minitest::Test
  def setup
    @provider = MyCustomProvider.new(api_key: "test")
  end

  def test_chat
    # Use VCR or Faraday test adapter
    response = @provider.chat(
      [{ role: "user", content: "Hello" }],
      model: "my-model"
    )
    assert response.assistant?
    assert response.content
  end
end
```

## Next Steps

- [Build a custom agent](/ask-docs/extending/custom-agents)
- [Publish a custom service gem](/ask-docs/extending/custom-services)
- [Create custom skills](/ask-docs/extending/custom-skills)
