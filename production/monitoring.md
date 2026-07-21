---
layout: default
title: Monitoring Dashboard
parent: Production
nav_order: 2
---

# Monitoring Dashboard

A Rails engine dashboard at `/ask/monitoring` for real-time visibility into your agents.

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
rails generate ask_monitoring:install
rails db:migrate
```

Mount the engine in `config/routes.rb`:

```ruby
mount Ask::Monitoring::Engine, at: "/ask"
```

Visit `/ask/monitoring` in your browser.

## Dashboard Metrics

| Metric | What It Shows |
|---|---|
| **Cost** | Total and per-model spend (daily, weekly, monthly) |
| **Throughput** | Requests per minute, average response time |
| **Errors** | Error rate by type (rate limit, auth, timeout, etc.) |
| **Active Sessions** | Currently running sessions |
| **Tool Usage** | Most-used tools and average execution time |
| **Model Distribution** | Which models are being used and how often |

## Alert Channels

Configure alerts for critical thresholds:

```ruby
Ask::Monitoring.configure do |c|
  # Slack alerts
  c.alert_channel :slack, webhook_url: ENV["SLACK_ALERT_WEBHOOK"]

  # Email alerts
  c.alert_channel :email, to: "team@example.com"

  # Webhook
  c.alert_channel :webhook, url: ENV["ALERT_WEBHOOK_URL"]
end
```

## Alert Rules

```ruby
Ask::Monitoring.configure do |c|
  c.alert_rules = [
    # Cost spike
    { metric: :cost, threshold: 10.0, window: "1h", channel: :slack },
    # Error rate
    { metric: :error_rate, threshold: 0.05, window: "5m", channel: :email },
    # Latency
    { metric: :p95_latency_ms, threshold: 30000, window: "5m", channel: :webhook }
  ]
end
```

## Custom Metrics

```ruby
Ask::Monitoring.track_metric(:custom_tool_usage, value: 42, tags: { tool: "bash" })

# View in dashboard under "Custom Metrics"
```

## Data Retention

```ruby
Ask::Monitoring.configure do |c|
  c.retention_days = 90  # Keep metrics for 90 days
end
```

## Next Steps

- [Configure OpenTelemetry tracing](/ask-docs/production/opentelemetry)
- [Evaluate LLM outputs](/ask-docs/production/evaluation)
- [Learn about observability events](/ask-docs/production/observability)
