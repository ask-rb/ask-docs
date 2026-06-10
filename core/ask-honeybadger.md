---
layout: default
title: ask-honeybadger
parent: ask-core
nav_order: 8
---

# ask-honeybadger

**Honeybadger error tracking context for AI agents.** Provides an authenticated HTTP client
for the Honeybadger Data API, metadata constants for system prompts, and a structured error
guide for common Honeybadger API issues. Depends on `ask-auth` for credential resolution
and `faraday ~> 2.0`.

```ruby
gem "ask-honeybadger"
```

## Quick Start

```ruby
require "ask-honeybadger"

client = Ask::Honeybadger.client
faults = client.get("/v2/projects/PROJECT_ID/faults")

# Or use the convenience helpers:
Ask::Honeybadger.recent_faults(project_id: "PROJECT_ID", limit: 10)
Ask::Honeybadger.fault_summary(project_id: "PROJECT_ID")
Ask::Honeybadger.fault(project_id: "PROJECT_ID", fault_id: 42)
Ask::Honeybadger.projects
```

## Authentication

The client resolves your Honeybadger API token via `Ask::Auth.resolve(:honeybadger_token)`.
Tokens can be provided through any configured provider:

1. **Environment variable:** `HONEYBADGER_TOKEN`
2. **Credentials file:** `~/.ask/credentials.yml`

Get your token at [app.honeybadger.io/users/edit](https://app.honeybadger.io/users/edit).

## Client

`Ask::Honeybadger.client` returns an authenticated `Faraday::Connection` configured with:

- **Base URL:** `https://app.honeybadger.io/v2`
- **Auth:** HTTP Basic Auth with token as username and blank password
- **Encoding:** JSON request/response
- **Retry:** 3 retries with exponential backoff on 429, 500, 502, 503

The client is wrapped in a `ClientProxy` that converts `Faraday::UnauthorizedError`
into `Ask::Auth::InvalidCredential` with actionable error messages.

```ruby
client = Ask::Honeybadger.client

# Raw API access
client.get("/v2/projects")
client.get("/v2/projects/ID/faults")
client.get("/v2/projects/ID/faults/FAULT_ID")
client.get("/v2/projects/ID/faults/summary")

# Convenience methods (accept kwargs for params like q:, order:, environment:)
Ask::Honeybadger.recent_faults(project_id: "ID", limit: 10, q: "RuntimeError")
Ask::Honeybadger.fault_summary(project_id: "ID")
Ask::Honeybadger.fault(project_id: "ID", fault_id: 42)
Ask::Honeybadger.projects
```

## Error Guide

`Ask::Honeybadger::Errors` provides structured knowledge for agents:

```ruby
# Look up guidance by exception class
Ask::Honeybadger::Errors.for("Faraday::ResourceNotFound")
# => { message: "The requested project or fault does not exist...", action: "Verify the project ID..." }

# Describe an HTTP status code
Ask::Honeybadger::Errors.status_code_description(401)
# => "Unauthorized — Token is missing, invalid, or revoked. Re-authenticate."

# Rate limit information
Ask::Honeybadger::Errors::RATE_LIMIT[:authenticated]
# => "360 requests per hour (using API token)"
```

Coverage includes all common Faraday exceptions: `UnauthorizedError`, `ForbiddenError`,
`ResourceNotFound`, `ParsingError`, `TimeoutError`, `ConnectionFailed`, `ServerError`.

## API

| Method / Constant | Returns | Purpose |
|---|---|---|
| `Ask::Honeybadger.client` | `Faraday::Connection` | Authenticated HTTP client |
| `Ask::Honeybadger.recent_faults(...)` | Hash | Latest faults for a project |
| `Ask::Honeybadger.fault_summary(...)` | Hash | Fault counts by environment/status |
| `Ask::Honeybadger.fault(...)` | Hash | Single fault details |
| `Ask::Honeybadger.projects` | Hash | All accessible projects |
| `Ask::Honeybadger::DESCRIPTION` | String | System prompt metadata |
| `Ask::Honeybadger::DOCS_URL` | String | API docs link |
| `Ask::Honeybadger::AUTH_NAME` | Symbol | `:honeybadger_token` |
| `Ask::Honeybadger::QUICK_START` | String | Copy-paste code snippet |
| `Ask::Honeybadger::Errors.for(klass)` | Hash or nil | Exception guidance |
| `Ask::Honeybadger::Errors.status_code_description(code)` | String or nil | HTTP status meaning |

## Context Constants

Used in system prompts to inform AI agents about Honeybadger capabilities:

```ruby
Ask::Honeybadger::DESCRIPTION  # => "Honeybadger — error tracking via the Honeybadger API"
Ask::Honeybadger::DOCS_URL     # => "https://docs.honeybadger.io/api/"
Ask::Honeybadger::AUTH_NAME    # => :honeybadger_token
Ask::Honeybadger::GEM_NAME     # => "honeybadger-ruby"
```

## Development

```bash
bundle install
bundle exec rake test    # 20 tests, 43 assertions
```

## Dependencies

- **Runtime:** `ask-core ~> 0.1`, `ask-auth ~> 0.1`, `faraday ~> 2.0`, `faraday-retry ~> 2.0`
- **Zero of our own runtime deps outside Faraday** — clean dependency tree

## Source

- GitHub: [github.com/ask-rb/ask-honeybadger](https://github.com/ask-rb/ask-honeybadger)
- RubyGems: [rubygems.org/gems/ask-honeybadger](https://rubygems.org/gems/ask-honeybadger)
