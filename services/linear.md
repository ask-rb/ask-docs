---
layout: default
title: Linear
parent: Service Contexts
nav_order: 4
---



**Linear integration for AI agents.** The `ask-linear` gem is **deprecated and unsupported** — do not add it to new projects.

## Recommendation

Prefer Linear's official MCP server for agent access to Linear. It is the supported path for agents working with issue tracking, project management, and roadmaps, and it replaces `ask-linear` entirely.

## Legacy Integration (Unsupported)

`ask-linear` is documented here only for teams that already depend on it. It receives no maintenance, and its installation instructions are obsolete.

What it provided:

- An authenticated GraphQL client against `https://api.linear.app/graphql`
- Context constants for system prompts (`DESCRIPTION`, `DOCS_URL`, `AUTH_NAME`)
- Structured error guidance (`Ask::Linear::Errors`) for GraphQL and HTTP errors
- Credential resolution through `ask-auth`

### Legacy Client Usage

<!-- docs-example: not-verified -->
```ruby
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

`client.query(gql, variables = {})` returned a `Hash` with a `"data"` key. The client used a 30-second read timeout, a 10-second open timeout, and up to 3 retries on 429, 500, 502, and 503 with exponential backoff. `Faraday::UnauthorizedError` (401) was converted into `Ask::Auth::InvalidCredential`.

### Legacy Credentials

Existing installs resolved a Linear API key via `ask-auth`: the `LINEAR_API_KEY` environment variable, `~/.ask/credentials.yml`, or Rails credentials (`linear_api_key`).

### Legacy Error Guidance

<!-- docs-example: not-verified -->
```ruby
# GraphQL error extension codes
Ask::Linear::Errors.for("AUTHENTICATION_ERROR")
# => { message: "The API key is missing, invalid, or has been revoked.", action: "..." }

# HTTP status meaning
Ask::Linear::Errors.status_code_description(401)
# => "Unauthorized — API key is missing, invalid, or revoked."

# Rate limits and pagination
Ask::Linear::Errors::RATE_LIMIT[:authenticated]
# => "100 requests per minute per API key"
Ask::Linear::Errors::PAGINATION[:cursor_based]
# => "Linear uses cursor-based pagination with first/after or last/before arguments."
```

The error guide covered GraphQL extension codes (`AUTHENTICATION_ERROR`, `FORBIDDEN`, `NOT_FOUND`, `RATE_LIMITED`, `INPUT_VALIDATION_ERROR`, `DUPLICATE_INPUT`, `INTERNAL_ERROR`, `USER_SUSPENDED`, `WORKSPACE_SUSPENDED`) and the corresponding HTTP status codes (400, 401, 403, 404, 422, 429, 500, 503).

## Next Steps

- [Build custom tools](/ask-docs/extending/custom-tools)
- [Explore the agent loop](/ask-docs/core/agent)
