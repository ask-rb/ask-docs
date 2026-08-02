---
layout: default
title: OpenTelemetry Tracing
parent: Production
nav_order: 3
---

# OpenTelemetry Tracing

Distributed tracing for your agents. `ask-opentelemetry` subscribes to `ask-instrumentation` events and wraps every LLM operation in an OpenTelemetry span. Export to Langfuse, Datadog, Honeycomb, Jaeger, Arize Phoenix, or any OpenTelemetry-compatible backend.

```ruby
gem "ask-opentelemetry"
```

## Quick Start

```ruby
require "ask/open_telemetry"

Ask::OpenTelemetry.install
```

That's the whole setup. In a Rails app the railtie installs it automatically on boot — no manual call needed. Safe to call repeatedly; subsequent calls are no-ops.

From here, every chat completion, tool call, embedding, and image generation gets a span.

## How Events Map to Spans

| Instrumentation Event | Span Name | Attributes |
|---|---|---|
| `chat.ask` / `chat.stream.ask` | `llm.chat` | `llm.provider`, `llm.model`, `llm.input_tokens`, `llm.output_tokens`, `llm.duration_ms` |
| `tool.ask` | `llm.tool` | `llm.tool`, `llm.tool_args`, `llm.duration_ms` |
| `embedding.ask` | `llm.embedding` | `llm.provider`, `llm.model`, `llm.duration_ms` |
| `image.ask` | `llm.image` | `llm.provider`, `llm.model`, `llm.image.size`, `llm.duration_ms` |

Metadata attached with `Ask::Instrumentation.with_metadata(user_id:, session_id:)` is forwarded as `llm.metadata.*` attributes on every span in that block.

## Exporters

ask-opentelemetry is backend-agnostic. It emits standard OpenTelemetry spans; the exporter is configured by the OpenTelemetry SDK in your app, the same way you'd configure it for any other tracing.

For example, an OTLP exporter pointed at Langfuse:

```ruby
require "opentelemetry-sdk"
require "opentelemetry-exporter-otlp"

OpenTelemetry::SDK.configure do |c|
  c.service_name = "my-agent"
  c.add_span_processor(
    OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
      OpenTelemetry::Exporter::OTLP::Exporter.new(
        endpoint: "https://cloud.langfuse.com/api/public/otel",
        headers: {
          "Authorization" => "Basic #{Base64.strict_encode64("#{ENV["LANGFUSE_PUBLIC_KEY"]}:#{ENV["LANGFUSE_SECRET_KEY"]}")}"
        }
      )
    )
  )
end
```

Datadog, Honeycomb, and Jaeger each ship their own OpenTelemetry exporters — same pattern, different endpoint. Point the SDK at them and the spans flow.

## Manual Instrumentation

Add custom spans around any code with the standard OpenTelemetry API:

```ruby
tracer = OpenTelemetry.tracer_provider.tracer("my-app")

tracer.in_span("custom.process") do |span|
  span.set_attribute("input.size", data.size)
  result = process(data)
  span.set_attribute("output.count", result.count)
  result
end
```

## Next Steps

- [Set up the monitoring dashboard](/ask-docs/production/monitoring)
- [Evaluate LLM outputs](/ask-docs/production/evaluation)
- [Learn about observability events](/ask-docs/production/observability)
