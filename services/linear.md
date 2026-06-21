---
layout: default
title: Linear
parent: Service Contexts
nav_order: 4
---



**Linear service context for AI agents.** Provides an authenticated GraphQL client, metadata constants for system prompts, and a structured error guide for agents working with the Linear API.

```ruby
gem "ask-linear"
```

## Quick Start

```ruby
require "ask-linear"

client = Ask::Linear.client

# List all teams
result = client.query("query { teams { nodes { id key name } } }")

# Create an issue
result = client.query(
  "mutation($input: IssueCreateInput!) { issueCreate(input: $input) { success issue { id identifier title url } } }",
  { input: { teamId: "TEAM_ID", title: "My issue", description: "Description here" } }
)

# Fetch a specific issue
result = client.query(
  "query($id: String!) { issue(id: $id) { id identifier title description state { name } assignee { name } url } }",
  { id: "ISSUE_ID" }
)
```

## Client API

### `Ask::Linear.client`

Returns an authenticated `Ask::Linear::Client` wrapped in a `ClientProxy` that converts `Faraday::UnauthorizedError` (HTTP 401) into `Ask::Auth::InvalidCredential` with actionable error messages.

```ruby
client = Ask::Linear.client
```

**Configuration:**
- 30-second read timeout
- 10-second open timeout
- Up to 3 retries on 429 (rate-limit), 500, 502, and 503 responses (with exponential backoff)

### `client.query(gql, variables = {})`

Executes a GraphQL query or mutation against `https://api.linear.app/graphql`.

| Argument | Type | Description |
|---|---|---|
| `gql` | String | The GraphQL query or mutation string |
| `variables` | Hash | Variables to interpolate into the query (optional, default: `{}`) |

**Returns:** `Hash` with a `"data"` key containing the response.

**Raises:**
- `Ask::Auth::MissingCredential` — no API key configured
- `Ask::Auth::InvalidCredential` — API key rejected (401)
- `ArgumentError` — invalid argument types passed
- `RuntimeError` — Linear returned GraphQL errors in the response
- `Faraday::Error` — network failure, timeout, or non-401 HTTP error

## Authentication

The client resolves a Linear API key via `Ask::Auth.resolve(:linear_api_key)`. API keys can be provided through any configured auth provider:

1. **Environment variable:** `LINEAR_API_KEY`
2. **Credentials file:** `~/.ask/credentials.yml`
3. **Rails credentials:** `Rails.application.credentials.linear_api_key`

Generate an API key at [linear.app/settings/api](https://linear.app/settings/api).

## Context Constants

Use these constants to build system prompts for AI agents:

| Constant | Value |
|---|---|
| `Ask::Linear::DESCRIPTION` | "Linear — issue tracking, project management, roadmaps, sprints" |
| `Ask::Linear::DOCS_URL` | https://developers.linear.app/docs |
| `Ask::Linear::GRAPHQL_URL` | https://api.linear.app/graphql |
| `Ask::Linear::AUTH_NAME` | `:linear_api_key` |
| `Ask::Linear::AUTH_HOW` | "https://linear.app/settings/api — generate a personal API key" |
| `Ask::Linear::GEM_NAME` | `"faraday"` |
| `Ask::Linear::GEM_VERSION` | `"~> 2.0"` |
| `Ask::Linear::QUICK_START` | Copy-paste Ruby code snippet with common GraphQL operations |

## Error Guide

`Ask::Linear::Errors` provides structured knowledge for agents:

```ruby
# Look up GraphQL error extension codes
Ask::Linear::Errors.for("AUTHENTICATION_ERROR")
# => { message: "The API key is missing, invalid, or has been revoked.",
#      action: "Generate a new API key at https://linear.app/settings/api..." }

# Describe HTTP status codes
Ask::Linear::Errors.status_code_description(401)
# => "Unauthorized — API key is missing, invalid, or revoked."

# Rate limit info
Ask::Linear::Errors::RATE_LIMIT[:authenticated]
# => "100 requests per minute per API key"

# Pagination guidance
Ask::Linear::Errors::PAGINATION[:cursor_based]
# => "Linear uses cursor-based pagination with first/after or last/before arguments."
```

### Supported GraphQL Error Codes

| Extension Code | When It Occurs |
|---|---|
| `AUTHENTICATION_ERROR` | Missing, invalid, or revoked API key |
| `FORBIDDEN` | API key lacks permission for the resource |
| `NOT_FOUND` | Resource doesn't exist or is inaccessible |
| `RATE_LIMITED` | API rate limit exceeded (100 req/min/key) |
| `INPUT_VALIDATION_ERROR` | Input data fails validation |
| `DUPLICATE_INPUT` | Resource with same data already exists |
| `INTERNAL_ERROR` | Linear server error |
| `USER_SUSPENDED` | Authenticated user account is suspended |
| `WORKSPACE_SUSPENDED` | Workspace is suspended or deactivated |

### HTTP Status Codes

| Status | Meaning |
|---|---|
| 200 | The request succeeded (check for GraphQL errors in body) |
| 400 | Malformed query or invalid variables |
| 401 | API key is missing, invalid, or revoked |
| 403 | API key lacks access to the resource |
| 404 | The requested resource does not exist |
| 422 | Validation failed — check request parameters |
| 429 | Rate limit exceeded (100 req/min/key) |
| 500 | Linear server issue — retry with backoff |
| 503 | Linear is temporarily unavailable — retry later |

## Development

```bash
bundle install
bundle exec rake test
```

## Source

- GitHub: [github.com/ask-rb/ask-linear](https://github.com/ask-rb/ask-linear)
- RubyGems: [rubygems.org/gems/ask-linear](https://rubygems.org/gems/ask-linear)

## Next Steps

- [Build custom tools](/extending/custom-tools)
- [Explore the agent loop](/core/agent)
