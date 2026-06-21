---
layout: default
title: GitHub
parent: Service Contexts
nav_order: 1
---



**GitHub service context for AI agents.** Provides an authenticated Octokit client,
metadata constants for system prompts, and a structured error guide for common
GitHub API issues. Depends on `ask-auth` for credential resolution and `octokit ~> 9.0`.

```ruby
gem "ask-github"
```

## Quick Start

```ruby
require "ask-github"

client = Ask::GitHub.client
client.issues("owner/repo")
client.create_issue("owner/repo", "Title", "Body")
client.pull_requests("owner/repo")
client.contents("owner/repo", path: "Gemfile")
client.search_issues("query")
```

## Authentication

The client resolves your GitHub token via `Ask::Auth.resolve(:github_token)`. Tokens
can be provided through any configured provider:

1. **Environment variable:** `GITHUB_TOKEN`
2. **Credentials file:** `~/.ask/credentials.yml`
3. **Rails credentials:** `Rails.application.credentials.github_token`

Generate a token at [github.com/settings/tokens](https://github.com/settings/tokens)
with the `repo` and `read:org` scopes.

## Client

`Ask::GitHub.client` returns an authenticated `Octokit::Client` configured with:

- `auto_paginate: true` — collect all pages automatically
- `per_page: 100` — maximum items per request
- Faraday retry middleware — 3 retries, exponential backoff on 429, 500, 502, 503

The client is wrapped in a `ClientProxy` that converts `Octokit::Unauthorized`
into `Ask::Auth::InvalidCredential` with actionable error messages.

```ruby
client = Ask::GitHub.client
client.issues("rails/rails")
client.create_issue("user/repo", "Bug report", "Details...")
client.pull_requests("user/repo", state: "open")
client.contents("user/repo", path: "README.md")
client.search_issues("label:bug")
```

## Error Guide

`Ask::GitHub::Errors` provides structured knowledge for agents:

```ruby
# Look up guidance by exception class
Ask::GitHub::Errors.for("Octokit::NotFound")
# => { message: "The requested repository...", action: "Verify the owner/repo name..." }

# Describe an HTTP status code
Ask::GitHub::Errors.status_code_description(404)
# => "Not Found — Resource does not exist or is private."

# Rate limit information
Ask::GitHub::Errors::RATE_LIMIT[:authenticated]
# => "5,000 requests per hour (using personal access token)"
```

Coverage includes all common Octokit exceptions: `Unauthorized`, `Forbidden`,
`NotFound`, `TooManyRequests`, `UnprocessableEntity`, `ServerError`,
`InvalidRepository`.

## API

| Method / Constant | Returns | Purpose |
|---|---|---|
| `Ask::GitHub.client` | `Octokit::Client` | Authenticated client |
| `Ask::GitHub::DESCRIPTION` | String | System prompt metadata |
| `Ask::GitHub::DOCS_URL` | String | REST API docs link |
| `Ask::GitHub::AUTH_NAME` | Symbol | `:github_token` |
| `Ask::GitHub::QUICK_START` | String | Copy-paste code snippet |
| `Ask::GitHub::Errors.for(klass)` | Hash or nil | Exception guidance |
| `Ask::GitHub::Errors.status_code_description(code)` | String or nil | HTTP status meaning |

## Context Constants

Used in system prompts to inform AI agents about GitHub capabilities:

```ruby
Ask::GitHub::DESCRIPTION  # => "GitHub — code hosting, issues, pull requests, actions, packages"
Ask::GitHub::DOCS_URL     # => "https://docs.github.com/en/rest"
Ask::GitHub::AUTH_NAME    # => :github_token
Ask::GitHub::GEM_NAME     # => "octokit"
```

## Development

```bash
bundle install
bundle exec rake test    # 31 tests, 78 assertions
bundle exec rake coverage  # with SimpleCov

# Run integration tests (requires GITHUB_TOKEN)
GITHUB_TOKEN=ghp_... bundle exec rake test
```

## Dependencies

- **Runtime:** `ask-auth ~> 0.1`, `octokit ~> 9.0`, `faraday-retry ~> 2.2`
- **Zero of our own runtime deps** — clean dependency tree

## Source

- GitHub: [github.com/ask-rb/ask-github](https://github.com/ask-rb/ask-github)
- RubyGems: [rubygems.org/gems/ask-github](https://rubygems.org/gems/ask-github)

## Next Steps

- [Build custom tools](/extending/custom-tools)
- [Learn about credentials](/core/auth)
