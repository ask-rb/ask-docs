---
layout: default
title: Custom Tools
parent: Extending
nav_order: 1
---

# Custom Tools

Build a tool from scratch. Tools are the primary way agents interact with the world — every capability your agent has comes through a tool.

## The Tool Contract

Every tool needs four things:

1. **A class** that subclasses `Ask::Tool`
2. **A description** — what this tool does
3. **Parameters** — what inputs it accepts
4. **An execute method** — the actual implementation

## Example: Weather Lookup Tool

```ruby
require "ask-tools"
require "net/http"
require "json"

class Weather < Ask::Tool
  description "Get current weather for a location"

  param :location, type: :string, desc: "City name (e.g., Tokyo, London)", required: true
  param :units, type: :string, desc: "Temperature unit", required: false

  def execute(location:, units: "celsius")
    api_key = ENV["WEATHER_API_KEY"]
    uri = URI("https://api.weatherapi.com/v1/current.json?key=#{api_key}&q=#{location}")
    response = Net::HTTP.get(uri)
    data = JSON.parse(response)

    Ask::Result.ok(data: {
      location: data["location"]["name"],
      temperature: data["current"]["temp_c"],
      conditions: data["current"]["condition"]["text"],
      humidity: data["current"]["humidity"]
    })
  rescue Net::HTTPError => e
    Ask::Result.error(message: "Weather API error: #{e.message}")
  end
end
```

## Using Your Tool

```ruby
# Standalone use
weather = Weather.new
result = weather.call(location: "Tokyo")
result.ok?    # => true
result.data   # => { location: "Tokyo", temperature: 22, ... }

# With an agent
session = Ask::Agent::Session.new(
  model: "gpt-4o",
  tools: [Weather]
)
session.run("What's the weather like in Tokyo today?")
```

## Tool DSL Reference

| Method | Description |
|---|---|
| `description(text)` | Sets the tool description shown to the LLM |
| `param(name, type:, desc:, required:)` | Declares a parameter |
| `execute(**args)` | Implement the tool's logic here |
| `name` | Auto-derived from class name (CamelCase → snake_case) |
| `params_schema` | JSON Schema for LLM function-calling APIs |

### Parameter Types

| Type | JSON Schema | Example |
|---|---|---|
| `:string` | `{ type: "string" }` | `param :name, type: :string` |
| `:integer` | `{ type: "integer" }` | `param :count, type: :integer` |
| `:number` | `{ type: "number" }` | `param :price, type: :number` |
| `:boolean` | `{ type: "boolean" }` | `param :active, type: :boolean` |
| `:array` | `{ type: "array", items: { type: ... } }` | `param :tags, type: :array` |
| `:object` | `{ type: "object" }` | `param :filter, type: :object` |

## Halting the Agent Loop

Raise `Ask::Tool::Halt` to stop the agent immediately:

```ruby
class SensitiveOperation < Ask::Tool
  description "Performs a sensitive operation requiring approval"
  param :action, type: :string, required: true

  def execute(action:)
    raise Ask::Tool::Halt, "Operation blocked: #{action} requires manual approval"
  end
end
```

The agent loop stops and returns the halt message to the user.

## Error Handling Conventions

```ruby
def execute(**args)
  # Happy path
  Ask::Result.ok(data: "Success")

  # Expected failure
  Ask::Result.error(message: "API returned 500")

  # Use exceptions for unexpected failures
  raise Ask::Tool::Halt, "Stop the agent"
end
```

## Testing Your Tool

```ruby
class WeatherTest < Minitest::Test
  def test_returns_weather
    tool = Weather.new
    result = tool.call(location: "London")

    assert result.ok?
    assert result.data[:temperature]
  end

  def test_handles_errors
    tool = Weather.new
    result = tool.call(location: "")

    refute result.ok?
    assert result.error
  end
end
```

## Registration

Tools auto-register with the tool registry when the class loads:

```ruby
Ask::Tools.all  # => [Weather.new, ...]
Ask::Tools["weather"]  # => Weather.new
```

Manual registration:

```ruby
Ask::Tools.register(Weather)
```

## Next Steps

- [Build a custom provider](/extending/custom-providers)
- [Create a custom agent](/extending/custom-agents)
- [Publish a custom service gem](/extending/custom-services)
