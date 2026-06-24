---
layout: default
title: Gem Index
parent: Reference
nav_order: 1
---

# Gem Index

The complete ask-rb ecosystem. All gems are independently versioned and released on RubyGems.


## Foundation

These gems have zero dependencies on other ask-rb gems. They form the bedrock of the ecosystem.

| Gem | Purpose |
|---|---|
| **[ask-core](https://github.com/ask-rb/ask-core)** | Defines the core abstractions every LLM application needs — conversation message containers that normalize roles, a streaming primitives for token-by-token responses, a provider interface that all LLM backends implement, and a model catalog that maps model names to their providers. Ships structured error types so errors bubble up cleanly. |
| **[ask-schema](https://github.com/ask-rb/ask-schema)** | A Ruby DSL for building JSON Schema hashes without writing raw hashes. Declare object shapes with `param`, `required`, and type constraints the same way you would in a Rails strong parameters block. Designed for LLM function-calling schemas. |
| **[ask-auth](https://github.com/ask-rb/ask-auth)** | A credential resolution chain that walks configured providers in order — environment variables, config files, Rails credentials, database-backed tokens, and OAuth flows — and returns the first match. Every service gem in the ecosystem calls `Ask::Auth.resolve(:service_token)` instead of reading env vars directly. |
| **[ask-sandbox-providers](https://github.com/ask-rb/ask-sandbox-providers)** | Four sandbox backends for safely executing untrusted code: Local process with resource limits (rlimits), Docker containers with read-only rootfs and no network, remote containers via the Daytona API, and Cloudflare Workers sandbox. Swap backends with a single assignment — `Ask::Sandbox.provider = Ask::Sandbox::Docker.new(...)`. |

## LLM Providers

| Gem | Purpose |
|---|---|
| **[ask-llm-providers](https://github.com/ask-rb/ask-llm-providers)** | Every LLM provider in a single gem. Ships concrete implementations of `Ask::Provider` for OpenAI (and compatible APIs), Anthropic, Google Gemini (both AI Studio and Vertex AI), AWS Bedrock, Ollama, Mistral AI, and Cloudflare Workers AI. Handles authentication, request serialization, streaming, and error normalization for each wire format. |

## Tools

These gems implement the `Ask::Tool` contract. Each tool is a standalone unit an agent can call.

| Gem | Purpose |
|---|---|
| **[ask-tools](https://github.com/ask-rb/ask-tools)** | The tool framework itself. Defines `Ask::Tool` — the base class every tool inherits from — along with `Ask::Result` (a standardized success/error return type), a thread-safe registry for discovering and looking up tools by name, and a scaffold generator for writing new tools. This gem ships no executable tools; it only provides the contract. |
| **[ask-tools-shell](https://github.com/ask-rb/ask-tools-shell)** | Seven execution tools every agent needs: `Bash` for shell commands in a sandboxed temp directory, `Read` for reading files with line numbers, `Write` for creating files with automatic parent directory creation, `Edit` for surgical string replacements, `Glob` for pattern-matching filenames, `Grep` for regex search across files (skipping `.git` and `node_modules`), and `Code` for executing Ruby in a sandboxed subprocess. Output is truncated at 100KB and timeouts are surfaced as errors. |
| **[ask-web-search](https://github.com/ask-rb/ask-web-search)** | A single `Ask::Tools::WebSearch` tool that queries a local SearXNG instance and formats results as a numbered markdown-like string with title, URL, and content snippet. Deduplicates by URL and includes infobox results. Configure the endpoint with the `SEARXNG_URL` environment variable — defaults to `http://localhost:8888`. |

## Agent

| Gem | Purpose |
|---|---|
| **[ask-agent](https://github.com/ask-rb/ask-agent)** | The core agent loop — think, call tools, execute, feed results back, repeat. Manages sessions (conversation state with an LLM), tool execution (resolving tool names to calls, passing results back as messages), conversation compaction (trimming history while preserving context), lifecycle hooks, and event emission. Ported from `RubyLLM::Conductor` into the `Ask::Agent` namespace. |

## Rails

| Gem | Purpose |
|---|---|
| **[ask-rails](https://github.com/ask-rb/ask-rails)** | Rails integration that wires the full ask-rb stack into your application. Ships a Railtie for auto-loading gems, ActiveRecord-backed session persistence, database query and schema inspection tools, a generator for the initializer and migration, and automatic discovery of installed service gems so agents know what integrations are available. |

## MCP

| Gem | Purpose |
|---|---|
| **[ask-mcp](https://github.com/ask-rb/ask-mcp)** | A full Model Context Protocol client for Ruby. Connect to MCP servers via stdio (subprocess), SSE (Server-Sent Events), or Streamable HTTP. Discover tools, resources, and prompts from any MCP server — the same protocol used by Claude Code, Codex, Cursor, and GitHub Copilot. Supports OAuth 2.1 authentication. |

## Instrumentation & Observability

| Gem | Purpose |
|---|---|
| **[ask-instrumentation](https://github.com/ask-rb/ask-instrumentation)** | Emits `ActiveSupport::Notifications` events for every LLM operation — chat completions, embeddings, tool calls, and image generation. Works with any provider. Subscribe to events for cost tracking, custom logging, analytics dashboards, or alerting. The foundation that all other observability gems build on. |
| **[ask-opentelemetry](https://github.com/ask-rb/ask-opentelemetry)** | Subscribes to `ask-instrumentation` events and creates OpenTelemetry spans for every LLM operation. Works with any OpenTelemetry-compatible backend — Langfuse, Datadog, Honeycomb, Jaeger, Arize Phoenix, and more. Install and call `Ask::OpenTelemetry.install` to start tracing. |
| **[ask-monitoring](https://github.com/ask-rb/ask-monitoring)** | A Rails engine that provides a real-time monitoring dashboard at `/ask/monitoring`. Tracks cost, throughput, error rates, and response times for all LLM calls. Uses Hotwire Turbo to auto-refresh every 30 seconds. Ships Slack alert integration so your team gets notified when error rates spike. |

## Service Contexts

Service gems provide an authenticated client and contextual metadata so agents can interact with third-party APIs by writing Ruby code, not by learning raw HTTP.

| Gem | Purpose |
|---|---|
| **[ask-github](https://github.com/ask-rb/ask-github)** | Provides an authenticated Octokit client, system prompt context describing the GitHub API surface, and a structured error guide that helps agents diagnose and recover from common GitHub API errors. Manage issues, pull requests, repositories, and code search. |
| **[ask-slack](https://github.com/ask-rb/ask-slack)** | An authenticated Slack Web API client with system prompt context and error knowledge. Post messages to channels, list conversations, manage users, upload files, and search message history. |
| **[ask-notion](https://github.com/ask-rb/ask-notion)** | An authenticated Notion API client using the `notion-ruby-client` gem. Query databases, retrieve and create pages, search workspaces, and update page properties. Includes structured error knowledge for common Notion API errors. |
| **[ask-linear](https://github.com/ask-rb/ask-linear)** | An authenticated GraphQL client for the Linear API. List teams, create and update issues, query projects and cycles. Ships system prompt metadata and a structured error guide for the Linear API, all resolved via `ask-auth`. |
| **[ask-sentry](https://github.com/ask-rb/ask-sentry)** | A client for the Sentry error tracking API. List and inspect errors, project configuration, release tracking, and performance monitoring — all authenticated through `ask-auth`. |
| **[ask-honeybadger](https://github.com/ask-rb/ask-honeybadger)** | A client for the Honeybadger error tracking API. List recent faults, get fault summaries, inspect individual faults, and list projects. Authenticated through the shared credential resolution chain. |
| **[ask-solid_errors](https://github.com/ask-rb/ask-solid_errors)** | Accesses errors stored in your Rails database via the `solid_errors` gem. Query recent errors, inspect error details, and analyze error patterns — no API key needed since it reads directly from your database. |

## Skills

| Gem | Purpose |
|---|---|
| **[ask-skills](https://github.com/ask-rb/ask-skills)** | A skill discovery and loading system for agents. Searches project directories, user config paths, and installed gems for markdown skill files. Skills are listed in the agent's system prompt by name and description, then loaded on-demand when the agent decides it needs domain guidance. Ships built-in skills for codebase exploration and debugging methodology. |

## Evaluation

| Gem | Purpose |
|---|---|
| **[ask-eval](https://github.com/ask-rb/ask-eval)** | An LLM evaluation framework built on Minitest. Ships Minitest-native assertions — `assert_faithful` for verifying responses stay true to provided context, `assert_not_hallucinating` for detecting fabricated information, plus bias and toxicity checks. Uses LLM-as-judge for the semantic checks and deterministic assertions for basic checks. Outputs CI-native test results. |

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
