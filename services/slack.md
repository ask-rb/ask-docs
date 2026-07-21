---
layout: default
title: Slack
parent: Service Contexts
nav_order: 2
---



**Slack service context for the ask-rb ecosystem.** Provides an authenticated Slack Web API client,
context metadata, and structured error guidance for AI agents.

```ruby
gem "ask-slack"
```

## Quick Start

```ruby
require "ask-slack"

client = Ask::Slack.client
client.chat_postMessage(channel: "#general", text: "Hello from ask-rb!")
client.conversations_list
client.users_list
```

## Context Metadata

Available constants for AI system prompts:

| Constant | Value |
|----------|-------|
| `Ask::Slack::DESCRIPTION` | "Slack — messaging, channels, files, search, workspace management" |
| `Ask::Slack::DOCS_URL` | <https://api.slack.com/methods> |
<!-- OPENAPI_URL removed: Slack no longer serves the OpenAPI spec at a stable URL -->
| `Ask::Slack::AUTH_NAME` | `:slack_token` |
| `Ask::Slack::AUTH_HOW` | Create a Slack app at <https://api.slack.com/apps> |
| `Ask::Slack::GEM_NAME` | `slack-ruby-client` |
| `Ask::Slack::GEM_VERSION` | `~> 3.1` |
| `Ask::Slack::GEM_DOCS` | <https://rubydoc.info/gems/slack-ruby-client> |
| `Ask::Slack::QUICK_START` | Ruby code snippet with common client calls |

## Client

`Ask::Slack.client` returns an authenticated `Slack::Web::Client`:

```ruby
client = Ask::Slack.client
client.channels_list
client.conversations_history(channel: "C123456")
```

The client proxy converts authentication errors (`NotAuthed`, `InvalidAuth`,
`TokenRevoked`, `TokenExpired`, `AccountInactive`) into
`Ask::Auth::InvalidCredential` for consistent error handling.

## Error Guide

`Ask::Slack::Errors` provides structured knowledge for agents:

```ruby
# Look up guidance by error string
Ask::Slack::Errors.for("rate_limited")
# => { message: "Slack API rate limit exceeded.", action: "..." }

# HTTP status code descriptions
Ask::Slack::Errors.status_code_description(429)
# => "Too Many Requests — Rate limit exceeded. Use Retry-After header."

# Exception class mapping
Ask::Slack::Errors.exception_class("invalid_auth")
# => "Slack::Web::Api::Errors::InvalidAuth"
```

## Authentication

Set your Slack Bot User OAuth Token:

```bash
export SLACK_TOKEN=xoxb-your-bot-token-here
```

Or add it to `~/.ask/credentials.yml`:

```yaml
slack_token: xoxb-your-bot-token-here
```

## Dependencies

- **Runtime:** `ask-auth ~> 0.1`, `slack-ruby-client ~> 3.1`
- **Development:** minitest, mocha, rake

## Links

- **Source:** [github.com/ask-rb/ask-slack](https://github.com/ask-rb/ask-slack)
- **Issues:** [github.com/ask-rb/ask-slack/issues](https://github.com/ask-rb/ask-slack/issues)
- **RubyGems:** [rubygems.org/gems/ask-slack](https://rubygems.org/gems/ask-slack)

## Next Steps

- [Build custom tools](/ask-docs/extending/custom-tools)
- [Explore the agent loop](/ask-docs/core/agent)
