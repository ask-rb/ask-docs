---
layout: default
title: SolidErrors
parent: Service Contexts
nav_order: 7
---



**SolidErrors error tracking context for AI agents.** Provides an ActiveRecord proxy for
querying errors tracked by [SolidErrors](https://github.com/fractaledmind/solid_errors)
— a database-backed error tracker that runs in your Rails app.

No API tokens, no HTTP calls. SolidErrors stores errors in your Rails database, so
the client is a thin wrapper around `SolidErrors::Error` and `SolidErrors::Occurrence`.

```ruby
gem "ask-solid_errors"
```

## Prerequisites

Your Rails app must have `solid_errors` installed and its database migrated:

```ruby
gem "solid_errors"
```

```bash
bin/rails solid_errors:install:migrations
bin/rails db:migrate
```

## Quick Start

```ruby
require "ask-solid_errors"

# Last 10 errors
errors = Ask::SolidErrors.recent(limit: 10)
errors.map { |e| [e.id, e.exception_class, e.message.truncate(200)] }

# Find a specific error
error = Ask::SolidErrors.find(42)
error.backtrace
error.context
error.occurrences

# Unresolved errors (needs attention)
Ask::SolidErrors.unresolved

# Filter by class or severity
Ask::SolidErrors.by_class("ActiveRecord::RecordNotFound")
Ask::SolidErrors.by_severity("error")

# Search messages
Ask::SolidErrors.search("timeout")

# Count occurrences
Ask::SolidErrors.occurrence_count(error)
```

## Authentication

**None needed.** SolidErrors runs in the same database as your Rails application.
The client uses the existing ActiveRecord connection directly.

## Client

`Ask::SolidErrors.client` returns a `ClientProxy` that delegates to
`SolidErrors::Error`. All ActiveRecord query methods are available through
`method_missing`, so agents can chain scopes freely.

```ruby
client = Ask::SolidErrors.client
client.where(exception_class: "RuntimeError")
      .order(created_at: :desc)
      .limit(5)
```

The proxy provides these built-in convenience methods:

| Method | Returns | Purpose |
|---|---|---|
| `recent(limit: 10)` | ActiveRecord::Relation | Most recent errors |
| `unresolved` | ActiveRecord::Relation | Errors not yet resolved |
| `resolved` | ActiveRecord::Relation | Previously resolved errors |
| `find(id)` | SolidErrors::Error | Error by primary key |
| `occurrence_count(error)` | Integer | Occurrence count (by record or ID) |

## Module-Level Convenience Methods

All proxy methods are also available directly on `Ask::SolidErrors`:

```ruby
Ask::SolidErrors.recent(limit: 5)
Ask::SolidErrors.find(42)
Ask::SolidErrors.unresolved
Ask::SolidErrors.resolved
Ask::SolidErrors.by_class("RuntimeError")
Ask::SolidErrors.by_severity("error")
Ask::SolidErrors.search("timeout")
Ask::SolidErrors.occurrence_count(error)
```

## Error Guide

`Ask::SolidErrors::Errors` provides structured guidance for common Rails exceptions:

```ruby
# Look up guidance by exception class
Ask::SolidErrors::Errors.for("ActiveRecord::RecordNotFound")
# => { message: "A record was not found...", action: "Check that the ID exists..." }

# Describe a severity level
Ask::SolidErrors::Errors.severity_description("error")
# => { description: "🔥 An actual error occurred...", action: "Prioritize review..." }
```

Covers 18 common exception classes: `ActiveRecord::RecordNotFound`,
`ActiveRecord::RecordInvalid`, `ActiveRecord::StatementInvalid`,
`ActiveRecord::Migration::PendingMigrationError`,
`ActionController::RoutingError`, `ActionController::ParameterMissing`,
`Net::ReadTimeout`, `Net::OpenTimeout`, and more.

### Database Schema Reference

```ruby
Ask::SolidErrors::Errors::DATABASE[:table_structure]["solid_errors"]
# => ["exception_class (text)", "message (text)", "severity (text)", ...]
```

## Context Constants

Used in system prompts to inform AI agents about SolidErrors capabilities:

```ruby
Ask::SolidErrors::DESCRIPTION  # => "SolidErrors — error tracking stored in your Rails database"
Ask::SolidErrors::GEM_NAME     # => "solid_errors"
```

## Development

```bash
bundle install
bundle exec rake test  # 41 tests, 76 assertions
```

## Dependencies

- **Runtime:** `ask-core ~> 0.1`, `solid_errors`
- **No external HTTP calls** — reads directly from the Rails database

## Source

- GitHub: [github.com/ask-rb/ask-solid_errors](https://github.com/ask-rb/ask-solid_errors)
- RubyGems: [rubygems.org/gems/ask-solid_errors](https://rubygems.org/gems/ask-solid_errors)

## Next Steps

- [Set up Rails error monitoring](/rails/errors)
- [Learn about observability](/production/observability)
