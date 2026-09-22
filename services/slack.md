---
layout: default
title: Slack
parent: Service Contexts
nav_order: 2
---



**Slack integration for AI agents.** The `ask-slack` gem is **deprecated and unsupported** — do not add it to new projects.

## Recommendation

Prefer Slack's official MCP server for agent access to Slack. It is the supported path for agents working with messaging, channels, files, and workspace management, and it replaces `ask-slack` entirely.

## Legacy Integration (Unsupported)

`ask-slack` is documented here only for teams that already depend on it. It receives no maintenance, and its installation instructions are obsolete.

What it provided:

- An authenticated `Slack::Web::Client` (`Ask::Slack.client`)
- Context constants for system prompts (`DESCRIPTION`, `DOCS_URL`, `AUTH_NAME`)
- Structured error guidance (`Ask::Slack::Errors`) for common Slack API errors
- Credential resolution through `ask-auth`

### Legacy Client Usage

<!-- docs-example: not-verified -->
```ruby
client = Ask::Slack.client
client.chat_postMessage(channel: "#general", text: "Hello from ask-rb!")
client.conversations_list
client.conversations_history(channel: "C123456")
client.users_list
```

The client proxy converted authentication errors (`NotAuthed`, `InvalidAuth`, `TokenRevoked`, `TokenExpired`, `AccountInactive`) into `Ask::Auth::InvalidCredential` for consistent error handling.

### Legacy Credentials

Existing installs resolved a Bot User OAuth Token via `ask-auth`: the `SLACK_TOKEN` environment variable or `~/.ask/credentials.yml` (`slack_token`).

### Legacy Error Guidance

<!-- docs-example: not-verified -->
```ruby
# Guidance by error string
Ask::Slack::Errors.for("rate_limited")
# => { message: "Slack API rate limit exceeded.", action: "..." }

# HTTP status meaning
Ask::Slack::Errors.status_code_description(429)
# => "Too Many Requests — Rate limit exceeded. Use Retry-After header."

# Exception class mapping
Ask::Slack::Errors.exception_class("invalid_auth")
# => "Slack::Web::Api::Errors::InvalidAuth"
```

## Next Steps

- [Build custom tools](/ask-docs/extending/custom-tools)
- [Explore the agent loop](/ask-docs/core/agent)
