---
layout: default
title: Honeybadger
parent: Service Contexts
nav_order: 6
---



**Honeybadger integration for AI agents.** The `ask-honeybadger` gem is **deprecated and unsupported** — do not add it to new projects.

## Recommendation

Prefer Honeybadger's official MCP server for agent access to Honeybadger. It is the supported path for agents working with error tracking, faults, and projects, and it replaces `ask-honeybadger` entirely.

## Legacy Integration (Unsupported)

`ask-honeybadger` is documented here only for teams that already depend on it. It receives no maintenance, and its installation instructions are obsolete.

What it provided:

- An authenticated Faraday client for the Honeybadger Data API (`https://app.honeybadger.io/v2`)
- Convenience helpers (`recent_faults`, `fault_summary`, `fault`, `projects`)
- Context constants for system prompts (`DESCRIPTION`, `DOCS_URL`, `AUTH_NAME`)
- Structured error guidance (`Ask::Honeybadger::Errors`) for common Honeybadger API errors
- Credential resolution through `ask-auth`

### Legacy Client Usage

<!-- docs-example: not-verified -->
```ruby
client = Ask::Honeybadger.client

# Raw API access
client.get("/v2/projects")
client.get("/v2/projects/ID/faults")
client.get("/v2/projects/ID/faults/FAULT_ID")
client.get("/v2/projects/ID/faults/summary")

# Convenience helpers (kwargs like q:, order:, environment: were accepted)
Ask::Honeybadger.recent_faults(project_id: "ID", limit: 10, q: "RuntimeError")
Ask::Honeybadger.fault_summary(project_id: "ID")
Ask::Honeybadger.fault(project_id: "ID", fault_id: 42)
Ask::Honeybadger.projects
```

The client used HTTP Basic Auth (token as username, blank password), JSON encoding, and 3 retries with exponential backoff on 429, 500, 502, 503. `Faraday::UnauthorizedError` was converted into `Ask::Auth::InvalidCredential`.

### Legacy Credentials

Existing installs resolved a Honeybadger API token via `ask-auth`: the `HONEYBADGER_TOKEN` environment variable or `~/.ask/credentials.yml` (`honeybadger_token`).

### Legacy Error Guidance

<!-- docs-example: not-verified -->
```ruby
# Guidance by exception class
Ask::Honeybadger::Errors.for("Faraday::ResourceNotFound")
# => { message: "The requested project or fault does not exist...", action: "Verify the project ID..." }

# HTTP status meaning
Ask::Honeybadger::Errors.status_code_description(401)
# => "Unauthorized — Token is missing, invalid, or revoked. Re-authenticate."

# Rate limit information
Ask::Honeybadger::Errors::RATE_LIMIT[:authenticated]
# => "360 requests per hour (using API token)"
```

Coverage included the common Faraday exceptions: `UnauthorizedError`, `ForbiddenError`, `ResourceNotFound`, `ParsingError`, `TimeoutError`, `ConnectionFailed`, `ServerError`.

## Next Steps

- [Set up Rails error monitoring](/ask-docs/rails/errors)
- [Learn about observability](/ask-docs/production/observability)
