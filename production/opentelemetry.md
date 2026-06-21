---
layout: default
title: OpenTelemetry Tracing
parent: Production
nav_order: 3
---

# OpenTelemetry Tracing

Distributed tracing for your agents. Export spans to Langfuse, Datadog, Honeycomb, Jaeger, or any OpenTelemetry-compatible backend.

```ruby
gem "ask-opentelemetry"
```

## Quick Start

```ruby
require "ask/opentelemetry"

Ask::OpenTelemetry.setup(
  service_name: "my-agent",
  exporter: :langfuse,
  langfuse_secret_key: ENV["LANGFUSE_SECRET_KEY"],
  langfuse_public_key: ENV["LANGFUSE_PUBLIC_KEY"],
  langfuse_host: "https://cloud.langfuse.com"
)
```

## How Spans Map to Events

Each agent event maps to an OpenTelemetry span:

| Event | Span Name | Attributes |
|---|---|---|
| `LlmCallStart` → `LlmCallComplete` | `llm.call` | `llm.model`, `llm.input_tokens`, `llm.output_tokens`, `llm.cost` |
| `ToolExecutionStart` → `ToolExecutionComplete` | `tool.execute` | `tool.name`, `tool.duration_ms`, `tool.status` |
| `TurnComplete` | `agent.turn` | `turn.number`, `turn.tool_calls` |
| `SessionComplete` | `agent.session` | `session.turns`, `session.total_cost` |

## Exporters

### Langfuse

```ruby
Ask::OpenTelemetry.setup(
  service_name: "my-agent",
  exporter: :langfuse,
  langfuse_secret_key: ENV["LANGFUSE_SECRET_KEY"],
  langfuse_public_key: ENV["LANGFUSE_PUBLIC_KEY"]
)
```

### Datadog

```ruby
Ask::OpenTelemetry.setup(
  service_name: "my-agent",
  exporter: :datadog,
  datadog_agent_url: "http://localhost:8126"
)
```

### Honeycomb

```ruby
Ask::OpenTelemetry.setup(
  service_name: "my-agent",
  exporter: :honeycomb,
  honeycomb_api_key: ENV["HONEYCOMB_API_KEY"],
  honeycomb_dataset: "ask-agent"
)
```

### Jaeger (local dev)

```ruby
Ask::OpenTelemetry.setup(
  service_name: "my-agent",
  exporter: :jaeger,
  jaeger_host: "localhost",
  jaeger_port: 6831
)
```

## Trace Context Propagation

Pass trace context across service boundaries:

```ruby
# Extract from incoming request headers
context = Ask::OpenTelemetry.extract(rack_request.headers)

# Create session with trace context
session = Ask::Agent::Session.new(
  model: "gpt-4o",
  trace_context: context
)

# Inject to outgoing requests
headers = {}
Ask::OpenTelemetry.inject(headers)
Faraday.get(url, headers: headers)
```

## Manual Instrumentation

Add custom spans around any code:

```ruby
Ask::OpenTelemetry.in_span("custom.process") do |span|
  span.set_attribute("input.size", data.size)
  result = process(data)
  span.set_attribute("output.count", result.count)
  result
end
```

## Configuration

```ruby
Ask::OpenTelemetry.configure do |c|
  c.service_name = "my-agent"
  c.service_version = "1.0.0"
  c.environment = Rails.env
  c.sample_rate = 1.0  # Sample all requests (0.0 - 1.0)
end
```

## Next Steps

- [Set up the monitoring dashboard](/production/monitoring)
- [Evaluate LLM outputs](/production/evaluation)
- [Learn about observability events](/production/observability)
