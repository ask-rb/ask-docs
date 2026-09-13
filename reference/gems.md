---
layout: default
title: Gem Index
parent: Reference
nav_order: 1
---

# Gem Index

The complete ask-rb ecosystem: 40+ Ruby gems, plus one npm package for UI components. All gems are independently versioned and released on RubyGems. Each gem's README is the front door; the guides below go deep.

## Which gems do you need?

Start from what you're building, not from the gem list. Every gem declares its own dependencies, so the tree below is all you add to your Gemfile.

| You want to... | Add to your Gemfile |
|---|---|
| Run an agent in any Ruby app (chatbot, coding assistant, research) | `ask-agent` (pulls in providers, tools, skills, state) |
| Add shell/file tools to that agent | `ask-agent` + `ask-tools-shell` |
| Give your Rails users AI features (agents, actions, workflows) | `ask-rails` (+ `ask-graph` for workflows) |
| Give an admin agent safe access to any Ruby project | `ask-ruby-harness` |
| Give an admin agent safe access to your Rails app | `ask-rails-harness` (builds on `ask-ruby-harness`) |
| Let Claude Code / Cursor introspect any Ruby project | `ask-ruby-harness-mcp` |
| Let Claude Code / Cursor introspect your Rails app | `ask-rails-harness-mcp` |
| Build a deterministic multi-step pipeline | `ask-graph` |
| Ground answers in your own documents | `ask-rag` |
| Talk to a specific LLM API without an agent | `ask-llm-providers` |
| Let an agent use your desktop apps | `ask-computer` |
| Call GitHub, Slack, Notion, Linear, Sentry, Honeybadger from an agent | the matching `ask-*` service gem |
| Fetch a URL as clean markdown | `ask-web-fetch` |
| Bill for token usage | `ask-tokens` (+ `ask-tokens-rails` for ActiveRecord) |
| Give every app a stable `https://<app>.localhost` URL | `yamine` |
| Expose the agent over the session protocol | `ask-app-server` + `ask-session-protocol` |
| Drive the agent from a terminal | `ask-terminal` |
| Monitor cost and latency in production | `ask-monitoring` (+ `ask-observability` for Prometheus/OTel) |
| Trace requests with OpenTelemetry | `ask-opentelemetry` |
| Test LLM outputs in Minitest | `ask-eval` |
| Expose your Ruby tools to any MCP client | `ask-mcp` |
| Build a chat UI | `ask-ui-kit` (npm) |

Don't add gems you don't need. `ask-agent` alone gets you a working agent; everything else layers on.

## Coding Agent

| Gem | Purpose |
|---|---|
| **[ask-app-server](https://github.com/ask-rb/ask-app-server)** | JSON-RPC/stdio app server exposing an ask-rb agent over the standard app-server protocol. [Guide](/ask-docs/core/app-server) |
| **[ask-session-protocol](https://github.com/ask-rb/ask-session-protocol)** | The canonical wire protocol for ask sessions: canonical events, resolvable interactions, versioned JSON Schema. [Guide](/ask-docs/core/session-protocol) |
| **[ask-terminal](https://github.com/ask-rb/ask-terminal)** | Terminal thin client for the session protocol: spawns or attaches to the host over stdio or a unix socket. [Guide](/ask-docs/core/terminal) |
| **[ask-coding-providers](https://github.com/ask-rb/ask-coding-providers)** | Registry of coding-agent adapters: `:acp`, `:ask_agent`, `:claude`, `:codex`. |

> `ask-coding-harness` is **deprecated** (maintenance mode). Build on `ask-app-server` + `ask-session-protocol` instead — [guide](/ask-docs/coding-agent).

## Foundation

| Gem | Purpose |
|---|---|
| **[ask-core](https://github.com/ask-rb/ask-core)** | Zero-dependency foundation: conversations, messages, streaming, provider interface, model catalog, result types, errors. [Guide](/ask-docs/core/ask-core) |
| **[ask-schema](https://github.com/ask-rb/ask-schema)** | Ruby DSL for JSON Schema, used by tool params and structured output. [Guide](/ask-docs/core/schema) |
| **[ask-auth](https://github.com/ask-rb/ask-auth)** | Credential resolution chain: env, files, Rails credentials, database, OAuth. [Guide](/ask-docs/core/auth) |
| **[ask-sandbox-providers](https://github.com/ask-rb/ask-sandbox-providers)** | Four sandbox backends for code execution: Local, Docker, Daytona, Cloudflare. [Guide](/ask-docs/core/sandbox) |
| **[ask-state-providers](https://github.com/ask-rb/ask-state-providers)** | State backends for sessions and checkpoints: Memory, SQLite, Redis, PostgreSQL, MySQL. [Reference](/ask-docs/reference/api#ask-state-providers) |

## LLM Providers

| Gem | Purpose |
|---|---|
| **[ask-llm-providers](https://github.com/ask-rb/ask-llm-providers)** | All providers in one gem: canonical + OpenAI-compatible, with a bundled model catalog. [Guide](/ask-docs/core/providers) |

## Tools

| Gem | Purpose |
|---|---|
| **[ask-tools](https://github.com/ask-rb/ask-tools)** | The tool framework: `Ask::Tool`, `Ask::Result`, registry. No executable tools inside. [Guide](/ask-docs/core/tools) |
| **[ask-tools-shell](https://github.com/ask-rb/ask-tools-shell)** | Nine shell and file tools: Bash, Read, Write, Edit, Glob, Grep, Code, Repl (persistent Ruby sessions), ApplyPatch. [Guide](/ask-docs/core/tools) |
| **[ask-web-search](https://github.com/ask-rb/ask-web-search)** | `Ask::Tools::WebSearch`, a SearXNG-backed search tool. [Guide](/ask-docs/core/web-search) |
| **[ask-web-fetch](https://github.com/ask-rb/ask-web-fetch)** | `Ask::WebFetch.fetch` — URL → clean markdown with pluggable backends (Local, Crawl4AI, Jina, Browser). [Guide](/ask-docs/core/web-fetch) |
| **[ask-computer](https://github.com/ask-rb/ask-computer)** | Drive desktop apps via Cua Driver: screenshots, clicks, typing, sandboxed VMs, encrypted Computer History. [Guide](/ask-docs/core/computer) |

## Agent

| Gem | Purpose |
|---|---|
| **[ask-agent](https://github.com/ask-rb/ask-agent)** | The agent loop: sessions, tool execution, compaction, hooks, events, evaluator, scheduler, sub-agents, `askr` CLI. [Guide](/ask-docs/core/agent) |

## Workflows

| Gem | Purpose |
|---|---|
| **[ask-graph](https://github.com/ask-rb/ask-graph)** | Deterministic, checkpointed multi-step workflows with conditions, parallelism, approval, timeouts, retries. [Guide](/ask-docs/core/graph) |

## Harness

| Gem | Purpose |
|---|---|
| **[ask-ruby-harness](https://github.com/ask-rb/ask-ruby-harness)** | Admin AI copilot for any Ruby project: 6 tools (DB, models, logs, commands, tests) with audit log and permissions. No Rails dependency. [Guide](/ask-docs/ruby/setup) |
| **[ask-ruby-harness-mcp](https://github.com/ask-rb/ask-ruby-harness-mcp)** | Exposes the harness tools to coding agents over MCP — serves any Ruby project, monorepo-aware. [Guide](/ask-docs/ruby/mcp) |

## Rails

| Gem | Purpose |
|---|---|
| **[ask-rails](https://github.com/ask-rb/ask-rails)** | Generators, file conventions, and a railtie for user-facing AI features in Rails. [Guide](/ask-docs/getting-started/rails-app) |
| **[ask-rails-harness](https://github.com/ask-rb/ask-rails-harness)** | Admin AI copilot mounted at `/ask`: the 6 generic tools plus `RouteInspector`, audit log, permissions, chat UI. Builds on `ask-ruby-harness`. [Guide](/ask-docs/rails/setup) |
| **[ask-rails-harness-mcp](https://github.com/ask-rb/ask-rails-harness-mcp)** | Exposes the harness tools to coding agents over MCP. [Guide](/ask-docs/rails/mcp) |

## MCP

| Gem | Purpose |
|---|---|
| **[ask-mcp](https://github.com/ask-rb/ask-mcp)** | MCP client and server for Ruby: stdio, SSE, Streamable HTTP, OAuth 2.1. [Guide](/ask-docs/core/mcp) |
| **[ask-web-search-mcp](https://github.com/ask-rb/ask-web-search-mcp)** | MCP server exposing `ask_web_search` over stdio for any MCP client. [Guide](/ask-docs/core/web-search) |
| **[ask-web-fetch-mcp](https://github.com/ask-rb/ask-web-fetch-mcp)** | MCP server exposing `ask_web_fetch` over stdio for any MCP client. [Guide](/ask-docs/core/web-fetch) |
| **[ask-computer-mcp](https://github.com/ask-rb/ask-computer-mcp)** | MCP server for `ask-computer` tools over stdio — use computer-use from any MCP client. [Guide](/ask-docs/core/computer) |

## Session Protocol & Clients

| Gem | Purpose |
|---|---|
| **[ask-session-protocol](https://github.com/ask-rb/ask-session-protocol)** | Canonical wire protocol for ask sessions: events, interactions, methods, versioning, JSON Schema. [Guide](/ask-docs/core/session-protocol) |
| **[ask-terminal](https://github.com/ask-rb/ask-terminal)** | Terminal client for the session protocol (command `ask`). Spawns or attaches to the host. [Guide](/ask-docs/core/terminal) |

## Instrumentation & Observability

| Gem | Purpose |
|---|---|
| **[ask-instrumentation](https://github.com/ask-rb/ask-instrumentation)** | `ActiveSupport::Notifications` events for every LLM operation. [Guide](/ask-docs/production/observability) |
| **[ask-opentelemetry](https://github.com/ask-rb/ask-opentelemetry)** | OpenTelemetry spans from instrumentation events. [Guide](/ask-docs/production/opentelemetry) |
| **[ask-observability](https://github.com/ask-rb/ask-observability)** | Prometheus metrics + OTel/logging bootstrap + `/metrics` endpoint. [Guide](/ask-docs/production/observability) |
| **[ask-monitoring](https://github.com/ask-rb/ask-monitoring)** | Rails engine dashboard for cost, throughput, error rate, response time, with alerts. [Guide](/ask-docs/production/monitoring) |

## Service Contexts

Service gems provide an authenticated client plus system-prompt metadata and error guidance for AI agents.

| Gem | Purpose |
|---|---|
| **[ask-github](https://github.com/ask-rb/ask-github)** | Authenticated Octokit client for issues, PRs, repos, search. [Guide](/ask-docs/services/github) |
| **[ask-slack](https://github.com/ask-rb/ask-slack)** | Slack Web API client for messaging and workspace management. [Guide](/ask-docs/services/slack) |
| **[ask-notion](https://github.com/ask-rb/ask-notion)** | Notion API client for pages, databases, blocks, search. [Guide](/ask-docs/services/notion) |
| **[ask-linear](https://github.com/ask-rb/ask-linear)** | GraphQL client for Linear issue tracking. [Guide](/ask-docs/services/linear) |
| **[ask-sentry](https://github.com/ask-rb/ask-sentry)** | Sentry error tracking API client. [Guide](/ask-docs/services/sentry) |
| **[ask-honeybadger](https://github.com/ask-rb/ask-honeybadger)** | Honeybadger fault tracking API client. [Guide](/ask-docs/services/honeybadger) |
| **[ask-solid_errors](https://github.com/ask-rb/ask-solid_errors)** | Database-backed error tracking via the solid_errors gem, no API key. [Guide](/ask-docs/services/solid_errors) |

## Channels

| Gem | Purpose |
|---|---|
| **[ask-channel-providers](https://github.com/ask-rb/ask-channel-providers)** | Messaging channel adapters with one interface. Ships Telegram today. |

## Skills

| Gem | Purpose |
|---|---|
| **[ask-skills](https://github.com/ask-rb/ask-skills)** | Skill discovery and loading: markdown methodology files from project, user config, gems, built-in. [Guide](/ask-docs/core/skills) |

## RAG

| Gem | Purpose |
|---|---|
| **[ask-rag](https://github.com/ask-rb/ask-rag)** | RAG pipeline: loaders, splitters, vector stores (InMemory, PGVector), retrieval, one-shot query. [Guide](/ask-docs/core/rag) |

## Tokens

| Gem | Purpose |
|---|---|
| **[ask-tokens](https://github.com/ask-rb/ask-tokens)** | Token accounting: count real tokens (tiktoken), price them, and run a wallet/ledger engine with a pluggable store. [Guide](/ask-docs/core/token-usage) |
| **[ask-tokens-rails](https://github.com/ask-rb/ask-tokens-rails)** | ActiveRecord store, `has_token_wallet`, install generator, and expiry sweep job for `ask-tokens`. [Guide](/ask-docs/core/token-usage) |

## Local Development

| Gem | Purpose |
|---|---|
| **[yamine](https://github.com/ask-rb/yamine)** | Stable named `https://<app>.localhost` URLs for Ruby development. Zero runtime dependencies. [Guide](/ask-docs/core/local) |
| ask-local-rails (deprecated) | Rails integration for `ask-local` — superseded by `RAILS_DEVELOPMENT_HOSTS` injection in core. Moved to deprecated/. |

## Evaluation

| Gem | Purpose |
|---|---|
| **[ask-eval](https://github.com/ask-rb/ask-eval)** | Minitest-native LLM evaluation: deterministic assertions, LLM-as-judge, session eval, recording/replay. [Guide](/ask-docs/production/evaluation) |

## UI Kit (npm)

| Package | Purpose |
|---|---|
| **[ask-ui-kit](https://github.com/ask-rb/ask-ui-kit)** | 16 framework-agnostic Web Components for AI chat UIs, built with Lit. [Guide](/ask-docs/core/ui-kit) |

## Dependency Graph

```
ask-core               ──► (no deps)
ask-schema             ──► (no deps)
ask-auth               ──► (no ask deps)
ask-sandbox-providers  ──► (no deps)
ask-state-providers    ──► ask-core
ask-skills             ──► (no deps)
ask-eval               ──► (no deps)
│
├── ask-llm-providers   ──► ask-core, ask-auth
├── ask-tools           ──► ask-schema
├── ask-graph           ──► ask-core, ask-state-providers
├── ask-instrumentation ──► (no ask deps)
│     ├── ask-opentelemetry ──► ask-instrumentation
│     ├── ask-observability ──► ask-instrumentation  (also Prometheus, OTel bootstrap, /metrics)
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
│     └── ask-agent  ──► ask-core, ask-llm-providers, ask-tools, ask-skills,
│                        ask-state-providers, ask-instrumentation
│           ├── ask-rails            ──► ask-agent
│           ├── ask-rails-harness    ──► ask-agent, ask-tools, ask-tools-shell, ask-auth
│           ├── ask-rails-harness-mcp ──► ask-rails-harness, ask-mcp
│           ├── ask-app-server       ──► ask-agent, ask-state-providers
│           │     └── ask-terminal        ──► ask-session-protocol  (client; also uses ask-app-server as host)
│           ├── ask-session-protocol ──► (no deps)  (used by ask-app-server + ask-terminal)
│           └── ask-coding-harness   ──► ask-agent, ask-coding-providers,  (deprecated)
│                                        ask-tools-shell, ask-state-providers
│
├── ask-web-search   ──► ask-tools
│     └── ask-web-search-mcp ──► ask-mcp, ask-web-search
├── ask-web-fetch    ──► ask-tools
│     └── ask-web-fetch-mcp  ──► ask-mcp, ask-web-fetch
├── ask-computer     ──► ask-core, ask-mcp, ask-tools
│     └── ask-computer-mcp ──► ask-computer, ask-mcp
├── ask-tokens       ──► (no deps)
│     └── ask-tokens-rails  ──► ask-tokens, activerecord
├── yamine           ──► (no deps)
│     └── ask-local-rails ──► yamine
├── ask-rag          ──► ask-core
│
└── ask-mcp          ──► (no ask deps)
      ├── ask-acp            ──► (no ask deps)
      └── ask-channel-providers ──► ask-auth
```

## Installation

```ruby
# Single gem
gem "ask-agent"

# The web coding agent — gem install ask-coding-harness, then `ach serve`
gem "ask-coding-harness"

# For Rails apps — user-facing AI features
gem "ask-rails"

# For Rails apps — admin copilot (pulls in agent, tools, shell, auth)
gem "ask-rails-harness"
```

All gems follow semantic versioning. Breaking changes increment the major version.

## Next Steps

- [Browse the API reference](/ask-docs/reference/api)
- [Learn about the design philosophy](/ask-docs/reference/design)
- [Get started with your first agent](/ask-docs/getting-started/first-agent)
