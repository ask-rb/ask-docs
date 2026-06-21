---
layout: default
title: Design & Philosophy
parent: Reference
nav_order: 3
---


# Design

The architecture, philosophy, and decisions behind `ask-rb`.

## Philosophy

1. **Providers own their protocols.** OpenAI knows how to talk OpenAI. Anthropic knows Anthropic. A provider gem ships
   with its own wire format, auth, and streaming. No shared "protocol layer" abstraction.

2. **Conversation, tools, and streaming are one thing.** A conversation contains tool calls. Streaming delivers
   conversations incrementally. They're always used together and ship in the same gem.

3. **Schema is the only shared primitive.** JSON Schema is used by tools AND structured output. It has zero LLM
   dependencies and stands alone.

4. **Auth is part of the provider.** Each provider knows how to authenticate. API keys, OAuth, token refresh —
   provider-specific. The core provides reusable helpers (env var resolution, PKCE OAuth flow).

5. **Tools are separate from the agent loop.** Tool definitions and implementations (bash, read, write, etc.) are
   useful without an agent loop — batch scripts, REPLs, CI pipelines. The agent loop (think → call → execute → feed
   back) is a separate concern.

6. **Everything has a programmatic API.** Every gem can be used from Ruby code directly, not just through a CLI.
   `Ask::Conversation.new`, `Ask::Tools::Bash.new.call(...)`, `Ask::Provider::OpenAI.new.chat(...)`. No hidden state.

7. **Extensions are first-class.** Third-party code can hook into every lifecycle event, register new tools, add
   commands, modify messages. Extensions are Ruby modules, not separate processes.

8. **No required database.** In-memory is the default. ActiveRecord is an optional adapter.

## Gem map

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

## Use cases

| Use case | Gems | Agent loop? | DB? |
|----------|------|-------------|-----|
| Simple chatbot | `ask-core` + provider | No | No |
| One-shot tool call | `ask-core` + `ask-tools` + provider | No | No |
| Coding assistant | `ask-core` + `ask-tools` + `ask-agent` + providers | Yes | Optional |
| Rails agent | `ask-core` + `ask-tools` + `ask-agent` + `ask-rails` | Yes | Yes (AR) |

## Lessons learned

These issues were discovered while building `llm-proxy` using RubyLLM v1.15.0 and directly shaped the `ask-rb` design:

- **Tool names must be explicit** — anonymous class names produce empty strings
- **Empty conversations must be validated** — never forward a malformed request
- **Tool registration should warn on collision** — silent overwrites hide bugs
- **Streaming should be per-request, not a mode flag** — no mutation
- **Parameter order must be preserved** — JSON Schema needs positional-aware builders
- **First-class hooks from day one** — no monkey-patching
- **Standard tool results** — every tool returns `Ask::Result` with `.ok?`, `.output`, `.error`
- **Shared role mapping** — one `Ask::RoleMap` used by all providers
