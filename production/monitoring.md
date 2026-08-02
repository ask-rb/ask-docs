---
layout: default
title: Monitoring Dashboard
parent: Production
nav_order: 2
---

# Monitoring Dashboard

A Rails engine at `/ask/monitoring` showing live cost, throughput, error rate, and response time for every LLM call in your app. Updates via Hotwire Turbo every 30 seconds — no Redis, no ActionCable.

```ruby
gem "ask-monitoring"
```

## Setup

```ruby
# Gemfile
gem "ask-monitoring"
gem "ask-instrumentation"  # required dependency
```

```bash
bundle install
rails generate ask:monitoring:install
rails db:migrate
```

Mount the engine in `config/routes.rb`:

```ruby
mount Ask::Monitoring::Engine, at: "/ask/monitoring"
```

Visit `/ask/monitoring` in your browser.

## Dashboard

| Metric | What It Shows |
|---|---|
| **Total Cost** | Spend in USD, calculated from token counts × model pricing |
| **Requests** | Request count in the selected time range |
| **Error Rate** | Percentage of failed requests |
| **Response Time (p50)** | Median latency in milliseconds |

Filter by time range (1h, 24h, 7d, 30d), provider, or model.

## Cost tracking

Pricing is built in for 22 models across OpenAI, Anthropic, Google, Mistral, Cohere, and Bedrock:

```ruby
Ask::Monitoring::Cost.for("openai/gpt-4", tokens: { input: 100, output: 50 })
# => 0.006 (USD)
```

Register custom pricing for your own models:

```ruby
Ask::Monitoring::Cost.register("my-provider/my-model", input: 0.001, output: 0.002)
```

## Alerts

Alert rules are procs that receive a metrics hash and fire when they return true. Route alerts to Slack or email:

```ruby
Ask::Monitoring.configure do |config|
  config.alert_rules << {
    name: "High error rate",
    condition: ->(metrics) { metrics[:error_rate] > 0.05 },
    channels: [:slack]
  }
end
```

Slack alerts use Incoming Webhooks:

```ruby
channel = Ask::Monitoring::Channels::Slack.new(
  webhook_url: ENV["SLACK_WEBHOOK_URL"]
)
channel.deliver(alert)
```

Email alerts work the same way with `Channels::Email.new(from:, to:)`. Set `alert_cooldown` to stop repeated alerts from the same rule from spamming (default 5 minutes).

## Next Steps

- [Configure OpenTelemetry tracing](/ask-docs/production/opentelemetry)
- [Evaluate LLM outputs](/ask-docs/production/evaluation)
- [Learn about observability events](/ask-docs/production/observability)
