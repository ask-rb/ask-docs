---
layout: default
title: GitHub
parent: Service Contexts
nav_order: 1
---



**GitHub integration for AI agents.** The `ask-github` gem is **deprecated and unsupported** — do not add it to new projects.

## Recommendation

Prefer GitHub's official MCP server for agent access to GitHub. It is the supported path for agents working with issues, pull requests, repositories, and search, and it replaces `ask-github` entirely.

## Legacy Integration (Unsupported)

`ask-github` is documented here only for teams that already depend on it. It receives no maintenance, and its installation instructions are obsolete.

What it provided:

- An authenticated Octokit client (`Ask::GitHub.client`) with auto-pagination and retries
- Context constants for system prompts (`DESCRIPTION`, `DOCS_URL`, `AUTH_NAME`)
- Structured error guidance (`Ask::GitHub::Errors`) for common GitHub API errors
- Credential resolution through `ask-auth`

### Legacy Client Usage

<!-- docs-example: not-verified -->
```ruby
client = Ask::GitHub.client
client.issues("owner/repo")
client.create_issue("owner/repo", "Title", "Body")
client.pull_requests("owner/repo")
client.contents("owner/repo", path: "Gemfile")
client.search_issues("query")
```

The client returned an `Octokit::Client` configured with `auto_paginate: true`, `per_page: 100`, and Faraday retry middleware (3 retries, exponential backoff on 429, 500, 502, 503). `Octokit::Unauthorized` was converted into `Ask::Auth::InvalidCredential` with an actionable message.

### Legacy Credentials

Existing installs resolved a GitHub token via `ask-auth`: the `GITHUB_TOKEN` environment variable, `~/.ask/credentials.yml`, or Rails credentials (`github_token`).

### Legacy Error Guidance

<!-- docs-example: not-verified -->
```ruby
# Guidance by exception class
Ask::GitHub::Errors.for("Octokit::NotFound")
# => { message: "The requested repository...", action: "Verify the owner/repo name..." }

# HTTP status meaning
Ask::GitHub::Errors.status_code_description(404)
# => "Not Found — Resource does not exist or is private."

# Rate limit information
Ask::GitHub::Errors::RATE_LIMIT[:authenticated]
# => "5,000 requests per hour (using personal access token)"
```

Coverage included the common Octokit exceptions: `Unauthorized`, `Forbidden`, `NotFound`, `TooManyRequests`, `UnprocessableEntity`, `ServerError`, `InvalidRepository`.

## Next Steps

- [Build custom tools](/ask-docs/extending/custom-tools)
- [Learn about credentials](/ask-docs/core/auth)
