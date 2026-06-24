---
layout: default
title: Gem Index
parent: Reference
nav_order: 1
---

# Gem Index

The complete ask-rb ecosystem. All gems are independently versioned and released on RubyGems.

## Foundation

| Gem | Version | Dependencies | Purpose |
|---|---|---|---|
| **ask-core** | 0.2.0 | None | Foundation: Conversation, Provider interface, Streaming, ModelCatalog, Error types |
| **ask-schema** | 0.1.0 | None | JSON Schema DSL — zero dependencies |
| **ask-auth** | 0.1.0 | base64 | Credential resolution chain (env → file → Rails → DB → OAuth) |
| **ask-sandbox-providers** | 0.1.1 | None | Sandboxed execution: Local, Docker, Daytona, Cloudflare |

## LLM Providers

| Gem | Version | Dependencies | Purpose |
|---|---|---|---|
| **ask-llm-providers** | 0.2.1 | ask-core, ask-auth | All LLM providers in one gem (OpenAI, Anthropic, Google, Bedrock, Ollama, Mistral, Cloudflare) |

## Tools

| Gem | Version | Dependencies | Purpose |
|---|---|---|---|
| **ask-tools** | 0.2.1 | None | Tool framework: Ask::Tool base class, Ask::Result, registry and discovery |
| **ask-tools-shell** | 0.3.0 | ask-tools, ask-sandbox-providers | Shell and filesystem tools: Bash, Read, Write, Edit, Glob, Grep, Code |
| **ask-web-search** | 0.2.0 | ask-tools | Web search via SearXNG — Ask::Tools::WebSearch tool |

## Agent

| Gem | Version | Dependencies | Purpose |
|---|---|---|---|
| **ask-agent** | 0.2.0 | ask-core, ask-llm-providers, ask-tools, ask-skills | Agent loop: Session, Loop, ToolExecutor, Compactor, Hooks, Events |

## Rails

| Gem | Version | Dependencies | Purpose |
|---|---|---|---|
| **ask-rails** | 0.2.4 | ask-agent, ask-tools-shell, ask-auth, rails >= 7.1 | Rails integration: generators, persistence, database tools, service discovery |

## MCP

| Gem | Version | Dependencies | Purpose |
|---|---|---|---|
| **ask-mcp** | 0.1.0 | httpx, json-schema | MCP client — stdio, SSE, Streamable HTTP, OAuth 2.1 |

## Instrumentation & Observability

| Gem | Version | Dependencies | Purpose |
|---|---|---|---|
| **ask-instrumentation** | 0.2.0 | activesupport | ActiveSupport::Notifications events for LLM operations |
| **ask-opentelemetry** | 0.1.0 | ask-instrumentation, opentelemetry-api | OpenTelemetry tracing for LLM operations |
| **ask-monitoring** | 0.1.0 | ask-instrumentation, rails | Rails engine dashboard for LLM usage monitoring |

## Service Contexts

| Gem | Version | Dependencies | Purpose |
|---|---|---|---|
| **ask-github** | 0.1.2 | ask-auth, octokit | GitHub API — issues, PRs, repos, search |
| **ask-slack** | 0.1.2 | ask-auth, slack-ruby-client | Slack API — messaging, channels, files |
| **ask-notion** | 0.1.1 | ask-auth, notion-ruby-client | Notion API — pages, databases, search |
| **ask-linear** | 0.1.1 | ask-auth, faraday | Linear API — issues, project management |
| **ask-sentry** | 0.1.1 | ask-core, ask-auth, faraday | Sentry error tracking API |
| **ask-honeybadger** | 0.1.1 | ask-core, ask-auth, faraday | Honeybadger error tracking API |
| **ask-solid_errors** | 0.1.1 | ask-core | Database-backed error tracking (via solid_errors) |

## Skills

| Gem | Version | Dependencies | Purpose |
|---|---|---|---|
| **ask-skills** | 0.2.1 | None | Skill discovery and management — ships built-in skills (design, compose) |

## Evaluation

| Gem | Version | Dependencies | Purpose |
|---|---|---|---|
| **ask-eval** | 0.1.0 | None | LLM evaluation — Minitest-native assertions (faithful, hallucination, bias, toxicity) |

## Dependency Graph

```
ask-core           ──► (no deps)
ask-schema         ──► (no deps)
ask-auth           ──► (no ask deps)
ask-sandbox-providers ──► (no deps)
ask-skills         ──► (no deps)
ask-eval           ──► (no deps)
  │
  ├── ask-llm-providers   ──► ask-core, ask-auth
  ├── ask-tools           ──► ask-schema
  ├── ask-instrumentation ──► (no ask deps)
  │     ├── ask-opentelemetry ──► ask-instrumentation
  │     └── ask-monitoring    ──► ask-instrumentation
  │
  ├── ask-github       ──► ask-auth
  ├── ask-slack        ──► ask-auth
  ├── ask-notion       ──► ask-auth
  ├── ask-linear       ──► ask-auth
  ├── ask-honeybadger  ──► ask-core, ask-auth
  ├── ask-sentry       ──► ask-core, ask-auth
  ├── ask-solid_errors ──► ask-core
  │
  ├── ask-tools-shell  ──► ask-tools, ask-sandbox-providers
  │     └── ask-agent  ──► ask-core, ask-llm-providers, ask-tools, ask-skills
  │           └── ask-rails  ──► ask-agent, ask-tools-shell, ask-auth
  │
  ├── ask-web-search   ──► ask-tools
  │
  └── ask-mcp          ──► (no ask deps)
```

## Installation

```ruby
# Single gem
gem "ask-agent"

# Or the full suite
gem "ask-rails"  # pulls in agent, tools, shell, auth
```

All gems follow semantic versioning. Breaking changes increment the major version.

## Next Steps

- [Browse the API reference](/reference/api)
- [Learn about the design philosophy](/reference/design)
- [Get started with your first agent](/getting-started/first-agent)
