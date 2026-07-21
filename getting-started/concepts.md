---
layout: default
title: Core Concepts
parent: Getting Started
nav_order: 3
---

# Core Concepts

The ask-rb ecosystem is organized around a few key concepts. Understand these and you'll understand how everything fits together.

## The Mental Model

```
You ──> Agent ──> Tools ──> World
          │
          └──> Provider ──> LLM
```

- An **Agent** runs a loop: think → call tools → execute → feed results back
- **Tools** are capabilities the agent can use (bash, read, write, SQL, API calls)
- A **Provider** connects to an LLM (OpenAI, Anthropic, Google, etc.)
- **Skills** guide *how* the agent approaches problems (methodology, not capability)

## What is an Agent?

An agent is a loop:

```
Turn 1: User says "Find the bug"
        LLM thinks: I should search the codebase
        LLM calls: grep(pattern: "TODO")
        Tool returns: "app/models/user.rb:42"
        LLM sees result, decides next step...

Turn 2: LLM thinks: Let me read that file
        LLM calls: read(path: "app/models/user.rb")
        Tool returns: file content
        LLM analyzes and responds...

Done: LLM provides answer
```

The loop runs until the agent answers the user or hits the turn limit (default 50).

## What is a Tool?

A **tool** is a single capability. Each tool has:

- A **name** — `bash`, `read`, `query_database`
- A **description** — "Execute shell commands in a sandboxed environment"
- **Parameters** — inputs the LLM can fill in
- An **execute** method — the Ruby code that runs when called

Tools are NOT skills. A tool gives the LLM a capability. A skill gives the LLM methodology.

```ruby
# A tool says "I can run bash commands"
# A skill says "When debugging, reproduce the bug first, then fix it"
```

## What is a Provider?

A **provider** is a wrapper around an LLM API. Each provider gem knows:

- The wire format (JSON-RPC, REST, etc.)
- Authentication (API key, OAuth, etc.)
- Streaming protocol (SSE, chunked, websocket)
- Error mapping (rate limits, auth errors, context length)

Providers are interchangeable. Switch from OpenAI to Anthropic by changing the model name:

```ruby
session = Ask::Agent::Session.new(model: "gpt-4o")          # OpenAI
session = Ask::Agent::Session.new(model: "claude-sonnet-4")  # Anthropic
session = Ask::Agent::Session.new(model: "gemini-2.0-flash") # Google
```

## What is a Skill?

A **skill** is a methodology — instructions that tell the agent *how* to approach a problem. Skills live in `.md` files and are loaded on demand:

```markdown
---
name: debugging
description: Systematic debugging methodology
---

When asked to debug:
1. Reproduce the issue first
2. Check logs and error messages
3. Isolate the root cause
4. Propose a fix with test
```

The key insight: skills are methodology, tools are capability. An agent can have all the tools in the world (capability) but without skills (methodology) it won't use them effectively.

## What is a Service Context?

A **service context** is a pre-built integration for an external service — GitHub, Slack, Notion, Linear, Sentry, Honeybadger. Each service gem provides:

- An **authenticated client** — ready to use, no setup beyond credentials
- **Context constants** — metadata for AI system prompts (DESCRIPTION, DOCS_URL, AUTH_NAME)
- **Error guidance** — structured knowledge about common API errors

## How Service Contexts Work

Service gems follow a three-file pattern:

```
ask-github/
├── lib/ask/github.rb          # Entry point: DESCRIPTION, AUTH_NAME, .client
├── lib/ask/github/client.rb   # Authenticated API client
└── lib/ask/github/errors.rb   # Structured error knowledge
```

They use `ask-auth` for credential resolution with a consistent chain:

```
ENV → ~/.ask/credentials.yml → Rails credentials → Database → OAuth
```

## The Gem Map

```
                    ┌──────────────────────────────────┐
                    │        Application Layer          │
                    │  (web app, CLI, desktop, mobile)   │
                    └──────────┬───────────────────────-┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
          ▼                    ▼                    ▼
    ┌──────────┐        ┌──────────┐         ┌──────────┐
    │ ask-core  │        │ ask-tools │         │ ask-agent  │
    └──────────┘        └──────────┘         └──────────┘
          │                    │                    │
          └────────────────────┼────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │      ask-schema      │
                    │   JSON Schema DSL    │
                    │    (zero deps)       │
                    └─────────────────────┘
```

## The Rules

1. **Providers own their protocols** — no shared abstraction layer
2. **Conversation, tools, and streaming are one thing** — always used together
3. **Schema is the only shared primitive** — JSON Schema has zero LLM dependencies
4. **Auth is part of the provider** — each knows how to authenticate
5. **Tools are separate from the agent loop** — useful without an agent
6. **Everything has a programmatic API** — use from Ruby code directly
7. **Extensions are first-class** — hook into every lifecycle event
8. **No required database** — in-memory is the default

## Next Steps

- [Build your first agent](/ask-docs/getting-started/first-agent) if you haven't yet
- [Explore all core components](/ask-docs/core)
- [Learn how service contexts work](/ask-docs/services)
- [Build a custom tool](/ask-docs/extending/custom-tools)
