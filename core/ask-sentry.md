---
layout: default
title: ask-sentry
parent: ask-core
nav_order: 7
---

# ask-sentry

**Sentry error tracking context for AI agents.** Provides an authenticated HTTP client
for the Sentry REST API, metadata constants for system prompts, and a structured error
guide for common Sentry API issues. Depends on `ask-auth` for credential resolution
and `faraday ~> 2.0`.

```ruby
gem "ask-sentry"
```

## Quick Start

```ruby
require "ask-sentry"

client = Ask::Sentry.client
issues = client.get("projects/ORG/PROJECT/issues/")

# Or use the convenience helpers:
Ask::Sentry.recent_errors(organization: "myorg", project: "myapp", limit: 10)
Ask::Sentry.issue_events(12345, limit: 10)
```

## Authentication

The client resolves your Sentry token via `Ask::Auth.resolve(:sentry_token)`.
Tokens can be provided through any configured provider:

1. **Environment variable:** `SENTRY_TOKEN`
2. **Credentials file:** `~/.ask/credentials.yml`

Generate a token at [sentry.io/settings/account/api/auth-tokens/](https://sentry.io/settings/account/api/auth-tokens/).

## Client

`Ask::Sentry.client` returns an authenticated `Faraday::Connection` configured with:

- **Base URL:** `https://sentry.io/api/0/`
- **Auth:** Bearer token authentication
- **Encoding:** JSON request/response
- **Retry:** 3 retries with exponential backoff on 429, 500, 502, 503

The client is wrapped in a `ClientProxy` that detects 401 responses and converts them
into `Ask::Auth::InvalidCredential` with actionable error messages.

```ruby
client = Ask::Sentry.client

# Raw API access
client.get("projects/ORG/PROJECT/issues/")
client.get("issues/ID/events/")

# Convenience methods
Ask::Sentry.recent_errors(organization: "myorg", project: "myapp", limit: 10)
Ask::Sentry.issue_events(12345, limit: 10)
```

## Error Guide

`Ask::Sentry::Errors` provides structured knowledge for agents:

```ruby
# Look up guidance by exception class
Ask::Sentry::Errors.for("Faraday::ResourceNotFound")
# => { message: "The requested project, issue, or resource does not exist...", action: "Verify the organization slug, project slug..." }

# Describe an HTTP status code
Ask::Sentry::Errors.status_code_description(401)
# => "Unauthorized — Auth token is missing, invalid, or revoked. Re-authenticate."

# Rate limit information
Ask::Sentry::Errors::RATE_LIMIT[:error_status]
# => 429
```

Coverage includes all common Faraday exceptions: `UnauthorizedError`, `ForbiddenError`,
`ResourceNotFound`, `TimeoutError`, `TooManyRequestsError`, `ClientError`, `ServerError`.

## API

| Method / Constant | Returns | Purpose |
|---|---|---|
| `Ask::Sentry.client` | `Faraday::Connection` | Authenticated HTTP client |
| `Ask::Sentry.recent_errors(organization:, project:, limit:)` | `Faraday::Response` | Latest issues for a project |
| `Ask::Sentry.issue_events(id, limit:)` | `Faraday::Response` | Events for a specific issue |
| `Ask::Sentry::DESCRIPTION` | String | System prompt metadata |
| `Ask::Sentry::DOCS_URL` | String | API docs link |
| `Ask::Sentry::AUTH_NAME` | Symbol | `:sentry_token` |
| `Ask::Sentry::QUICK_START` | String | Copy-paste code snippet |
| `Ask::Sentry::Errors.for(klass)` | Hash or nil | Exception guidance |
| `Ask::Sentry::Errors.status_code_description(code)` | String or nil | HTTP status meaning |

## Context Constants

Used in system prompts to inform AI agents about Sentry capabilities:

```ruby
Ask::Sentry::DESCRIPTION  # => "Sentry — error tracking via the Sentry API"
Ask::Sentry::DOCS_URL     # => "https://docs.sentry.io/api/"
Ask::Sentry::AUTH_NAME    # => :sentry_token
Ask::Sentry::GEM_NAME     # => "faraday"
```

## Development

```bash
bundle install
bundle exec rake test    # 32 tests, 65 assertions
```

## Dependencies

- **Runtime:** `ask-core ~> 0.1`, `ask-auth ~> 0.1`, `faraday ~> 2.0`, `faraday-retry ~> 2.0`
- **Zero of our own runtime deps outside Faraday** — clean dependency tree

## Source

- GitHub: [github.com/ask-rb/ask-sentry](https://github.com/ask-rb/ask-sentry)
- RubyGems: [rubygems.org/gems/ask-sentry](https://rubygems.org/gems/ask-sentry)
