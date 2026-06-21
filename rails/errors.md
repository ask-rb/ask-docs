---
layout: default
title: Error Services
parent: Rails Integration
nav_order: 4
---

# Error Services

Three error-tracking integrations — SolidErrors, Sentry, and Honeybadger — give your agent visibility into application errors.

## SolidErrors

**Database-backed error tracking.** Runs in your Rails database — no external API needed.

```ruby
gem "ask-solid_errors"
```

Prerequisites:

```ruby
gem "solid_errors"
```

```bash
bin/rails solid_errors:install:migrations
bin/rails db:migrate
```

Then use:

```ruby
# Recent errors
errors = Ask::SolidErrors.recent(limit: 10)
errors.map { |e| [e.id, e.exception_class, e.message.truncate(200)] }

# Unresolved errors
Ask::SolidErrors.unresolved

# Filter by class
Ask::SolidErrors.by_class("ActiveRecord::RecordNotFound")

# Search messages
Ask::SolidErrors.search("timeout")
```

**No authentication needed** — reads from your Rails database.

## Sentry

**Cloud-based error tracking.** Requires a Sentry API token.

```ruby
gem "ask-sentry"
```

```bash
export SENTRY_TOKEN="your-sentry-auth-token"
```

Then use:

```ruby
# Recent errors
Ask::Sentry.recent_errors(organization: "myorg", project: "myapp", limit: 10)

# Issue events
Ask::Sentry.issue_events(12345, limit: 10)
```

Generate a token at [sentry.io/settings/account/api/auth-tokens/](https://sentry.io/settings/account/api/auth-tokens/).

## Honeybadger

**Cloud-based error tracking.** Requires a Honeybadger API token.

```ruby
gem "ask-honeybadger"
```

```bash
export HONEYBADGER_TOKEN="your-honeybadger-token"
```

Then use:

```ruby
# Recent faults
Ask::Honeybadger.recent_faults(project_id: "PROJECT_ID", limit: 10)

# Fault summary
Ask::Honeybadger.fault_summary(project_id: "PROJECT_ID")

# Single fault
Ask::Honeybadger.fault(project_id: "PROJECT_ID", fault_id: 42)
```

Get your token at [app.honeybadger.io/users/edit](https://app.honeybadger.io/users/edit).

## Example: Debug with Error Context

```ruby
session = Ask::Rails.agent_session

# The agent can check errors and debug
response = session.run(
  "Check the recent errors and find out what's causing the spike in timeouts"
)

# The agent might:
# 1. Ask::SolidErrors.recent to check errors
# 2. ReadLog to correlate with log messages
# 3. QueryDatabase to check if there's a slow query
# 4. ReadModel on the affected model
# 5. Propose a fix
```

## Next Steps

- [Explore all error service gems](/services#error-tracking)
- [Learn about observability](/production/observability)
- [Evaluate LLM outputs](/production/evaluation)

## Links

- [Sentry service gem](/services/sentry) — Full API reference for Ask::Sentry
- [Honeybadger service gem](/services/honeybadger) — Full API reference for Ask::Honeybadger
- [SolidErrors service gem](/services/solid_errors) — Full API reference for Ask::SolidErrors
