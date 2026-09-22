---
layout: default
title: Sentry
parent: Service Contexts
nav_order: 5
---



**Sentry integration for AI agents.** The `ask-sentry` gem is **deprecated and unsupported** — do not add it to new projects.

## Recommendation

Prefer Sentry's official MCP server for agent access to Sentry. It is the supported path for agents working with error tracking, issues, and events, and it replaces `ask-sentry` entirely.

## Legacy Integration (Unsupported)

`ask-sentry` is documented here only for teams that already depend on it. It receives no maintenance, and its installation instructions are obsolete.

What it provided:

- An authenticated Faraday client for the Sentry REST API (`https://sentry.io/api/0/`)
- Convenience helpers (`recent_errors`, `issue_events`)
- Context constants for system prompts (`DESCRIPTION`, `DOCS_URL`, `AUTH_NAME`)
- Structured error guidance (`Ask::Sentry::Errors`) for common Sentry API errors
- Credential resolution through `ask-auth`

### Legacy Client Usage

<!-- docs-example: not-verified -->
```ruby
client = Ask::Sentry.client

# Raw API access
client.get("projects/ORG/PROJECT/issues/")
client.get("issues/ID/events/")

# Convenience helpers
Ask::Sentry.recent_errors(organization: "myorg", project: "myapp", limit: 10)
Ask::Sentry.issue_events(12345, limit: 10)
```

The client used bearer token authentication, JSON encoding, and 3 retries with exponential backoff on 429, 500, 502, 503. 401 responses were converted into `Ask::Auth::InvalidCredential`.

### Legacy Credentials

Existing installs resolved a Sentry token via `ask-auth`: the `SENTRY_TOKEN` environment variable or `~/.ask/credentials.yml` (`sentry_token`).

### Legacy Error Guidance

<!-- docs-example: not-verified -->
```ruby
# Guidance by exception class
Ask::Sentry::Errors.for("Faraday::ResourceNotFound")
# => { message: "The requested project, issue, or resource does not exist...", action: "..." }

# HTTP status meaning
Ask::Sentry::Errors.status_code_description(401)
# => "Unauthorized — Auth token is missing, invalid, or revoked. Re-authenticate."
```

Coverage included the common Faraday exceptions: `UnauthorizedError`, `ForbiddenError`, `ResourceNotFound`, `TimeoutError`, `TooManyRequestsError`, `ClientError`, `ServerError`.

## Next Steps

- [Set up Rails error monitoring](/ask-docs/rails/errors)
- [Learn about observability](/ask-docs/production/observability)
