---
layout: home
title: ask-rb
nav_order: 0
---

# 🌀 ask-rb

**A Ruby ecosystem for building with LLMs.**

`ask-rb` is a suite of Ruby gems for building any kind of LLM-powered application — coding assistants, chatbots, batch processors, desktop apps, RAG pipelines, and automated workflows.

```ruby
gem "ask-core"
gem "ask-llm-providers"
gem "ask-tools"
gem "ask-agent"
```

## What you'll find here

| Section | What's covered |
|---|---|
| [Getting Started](/ask-docs/getting-started) | Your first agent, Rails integration, core concepts |
| [Core Components](/ask-docs/core) | LLM providers, tools, sandboxes, agent loop, skills, schema, auth |
| [Rails Integration](/ask-docs/rails) | Setup, database tools, persistence, error services |
| [Service Contexts](/ask-docs/services) | GitHub, Slack, Notion, Linear, Sentry, Honeybadger |
| [Production](/ask-docs/production) | Observability, monitoring, tracing, evaluation |
| [Extending](/ask-docs/extending) | Custom tools, providers, agents, services, skills |
| [Reference](/ask-docs/reference) | Gem index, API docs, design philosophy |

## Design philosophy

1. **Providers own their protocols.** No shared abstraction layer. Each provider gem knows its own wire format, auth, and streaming.
2. **Conversation, tools, and streaming are one thing.** Always used together, shipped in the same gem.
3. **Schema is the only shared primitive.** JSON Schema has zero LLM dependencies and stands alone.
4. **Auth lives with the provider.** Each provider knows how to authenticate.
5. **Tools are separate from the agent loop.** Tool definitions are useful without an agent — batch scripts, REPLs, CI pipelines.
6. **Everything has a programmatic API.** Every gem can be used from Ruby code directly, not just through a CLI.
7. **Extensions are first-class.** Third-party code can hook into every lifecycle event.
8. **No required database.** In-memory is the default. ActiveRecord is an optional adapter.

## Ready to build?

Jump to [Getting Started](/ask-docs/getting-started/first-agent) and have an agent running in 5 minutes.
