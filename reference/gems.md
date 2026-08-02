---
layout: default
title: Gem Index
parent: Reference
nav_order: 1
---

# Gem Index

The complete ask-rb ecosystem: 30+ Ruby gems, plus one npm package for UI components. All gems are independently versioned and released on RubyGems.

## Which gems do you need?

Start from what you're building, not from the gem list. Every gem declares its own dependencies, so the tree below is all you add to your Gemfile.

| You want to... | Add to your Gemfile |
|---|---|
| Run an agent in any Ruby app (chatbot, coding assistant, research) | `ask-agent` (pulls in providers, tools, skills, state) |
| Add shell/file tools to that agent | `ask-agent` + `ask-tools-shell` |
| Give your Rails users AI features (agents, actions, workflows) | `ask-rails` (+ `ask-graph` for workflows) |
| Give an admin agent safe access to your Rails app | `ask-rails-harness` |
| Let Claude Code / Cursor introspect your Rails app | `ask-rails-harness-mcp` |
| Build a deterministic multi-step pipeline | `ask-graph` |
| Ground answers in your own documents | `ask-rag` |
| Talk to a specific LLM API without an agent | `ask-llm-providers` |
| Call GitHub, Slack, Notion, Linear, Sentry, Honeybadger from an agent | the matching `ask-*` service gem |
| Monitor cost and latency in production | `ask-monitoring` (+ `ask-instrumentation`) |
| Trace requests with OpenTelemetry | `ask-opentelemetry` |
| Test LLM outputs in Minitest | `ask-eval` |
| Expose your Ruby tools to any MCP client | `ask-mcp` |
| Build a chat UI | `ask-ui-kit` (npm) |

Don't add gems you don't need. `ask-agent` alone gets you a working agent; everything else layers on.

## Foundation

These gems have zero dependencies on other ask-rb gems. They form the bedrock of the ecosystem.

| Gem | Purpose |
|---|---|
| **[ask-core](https://github.com/ask-rb/ask-core)** | Defines the core abstractions every LLM application needs — conversation message containers that normalize roles, multi-modal content types (Text, Image, Audio, Video, File) for rich messages, streaming primitives for token-by-token responses, a provider interface that all LLM backends implement, a document value object for RAG pipelines, and a model catalog that maps model names to their providers. Ships structured error types so errors bubble up cleanly. |
| **[ask-schema](https://github.com/ask-rb/ask-schema)** | A Ruby DSL for building JSON Schema documents without writing raw hashes. Declare object shapes with type constraints the same way you would in a Rails strong parameters block. Designed for LLM function-calling schemas. Powers tool parameter schemas in ask-tools. |
| **[ask-auth](https://github.com/ask-rb/ask-auth)** | A credential resolution chain that walks configured providers in order — environment variables, config files, Rails credentials, database-backed tokens, and OAuth flows — and returns the first match. Every service gem in the ecosystem calls `Ask::Auth.resolve(:service_token)` instead of reading env vars directly. |
| **[ask-sandbox-providers](https://github.com/ask-rb/ask-sandbox-providers)** | Four sandbox backends for safely executing untrusted code: Local process with resource limits (rlimits), Docker containers with read-only rootfs and no network, remote containers via the Daytona API, and Cloudflare Workers sandbox. Swap backends with a single assignment — `Ask::Sandbox.provider = Ask::Sandbox::Docker.new(...)`. |
| **[ask-state-providers](https://github.com/ask-rb/ask-state-providers)** | Four state backends for persisting agent sessions — SQLite, Redis, PostgreSQL, and MySQL — plus `Ask::State::Memory`, the in-memory default. One `Ask::State::Adapter` contract, four databases, zero coupling to your infrastructure. Add the gem and a database driver when you need durability, resumability, or distributed state. |

## LLM Providers

| Gem | Purpose |
|---|---|
| **[ask-llm-providers](https://github.com/ask-rb/ask-llm-providers)** | Every LLM provider in a single gem — 33 total. Ships 7 canonical providers (OpenAI, Anthropic, Google Gemini, AWS Bedrock, Ollama, Mistral AI, Cloudflare Workers AI) with distinct wire formats and 26 OpenAI-compatible providers (DeepSeek, Groq, Together, Fireworks, Cerebras, xAI, Perplexity, DeepInfra, Anyscale, SambaNova, Nebius, Nvidia NIM, Friendli, Hyperbolic, Novita, Nscale, Featherless, AI/ML API, AI21, Meta, GitHub Models, OpenRouter, OpenCode, OpenCode Go, Mimo, Moonshot) configured via a data-driven registry — one line per provider, no subclass needed. All providers implement the `Ask::LLM::ProviderConfig` transformation contract (`build_request`, `parse_response`, `parse_stream`, `format_tools`, `format_message`) for testable, mechanical provider addition. Also ships 406 bundled model definitions with pricing (from models.dev and OpenRouter), alias resolution, and the `Ask::LLM::Catalog` loader. |

## Tools

These gems implement the `Ask::Tool` contract. Each tool is a standalone unit an agent can call.

| Gem | Purpose |
|---|---|
| **[ask-tools](https://github.com/ask-rb/ask-tools)** | The tool framework itself. Defines `Ask::Tool` — the base class every tool inherits from — along with `Ask::Result` (a standardized success/error return type), a thread-safe registry for discovering and looking up tools by name, and a scaffold generator for writing new tools. This gem ships no executable tools; it only provides the contract. |
| **[ask-tools-shell](https://github.com/ask-rb/ask-tools-shell)** | Eight execution tools every agent needs: `Bash` for shell commands in a sandboxed temp directory, `Read` for reading files with line numbers, `Write` for creating files with automatic parent directory creation, `Edit` for surgical string replacements, `Glob` for pattern-matching filenames, `Grep` for regex search across files (skipping `.git` and `node_modules`), `Code` for executing Ruby in a sandboxed subprocess, and `ApplyPatch` for unified-diff edits. Output is truncated at 100KB and timeouts are surfaced as errors. |
| **[ask-web-search](https://github.com/ask-rb/ask-web-search)** | A single `Ask::Tools::WebSearch` tool that queries a local SearXNG instance and formats results as a numbered markdown-like string with title, URL, and content snippet. Deduplicates by URL and includes infobox results. Configure the endpoint with the `SEARXNG_URL` environment variable — defaults to `http://localhost:8888`. |

## Agent

| Gem | Purpose |
|---|---|
| **[ask-agent](https://github.com/ask-rb/ask-agent)** | The core agent loop — think, call tools, execute, feed results back, repeat. Manages sessions (conversation state with an LLM), tool execution (resolving tool names to calls, passing results back as messages), conversation compaction (trimming history while preserving context), lifecycle hooks, event emission, and **independent response evaluation** through the `Evaluator` (a separate model judges output against a structured rubric). Also ships middleware, stream transforms, a scheduler for recurring runs, sub-agent delegation, and a CLI (`askr`). Ported from `RubyLLM::Conductor` into the `Ask::Agent` namespace. |

## Workflows

| Gem | Purpose |
|---|---|
| **[ask-graph](https://github.com/ask-rb/ask-graph)** | Durable workflow graphs. Define multi-step processes as plain Ruby classes with `call(context)` — conditional routing (`if:`/`unless:`), parallel steps, human-in-the-loop approval, per-item checkpointed loops, sub-workflow composition, step and workflow timeouts, retries with exponential backoff, and lifecycle hooks. Steps checkpoint after every completion; with a storage backend (any `Ask::State` adapter), a crashed workflow resumes from the last completed step. |

## Rails

| Gem | Purpose |
|---|---|
| **[ask-rails](https://github.com/ask-rb/ask-rails)** | Rails integration for building AI-powered applications. Provides generators (`rails generate ask:install`, `ask:agent`, `ask:action`, `ask:workflow`), file conventions (`app/agents/`, `app/actions/`, `app/workflows/`), a railtie that wires Zeitwerk and boot-time tool loading, an ActiveRecord-backed `Ask::Rails::State` adapter, and the `Ask::Actions` dispatch system for calling business logic from any channel. |
| **[ask-rails-harness](https://github.com/ask-rb/ask-rails-harness)** | Admin AI copilot for Rails apps. Mounts as a Rails Engine at `/ask` with 9 Rails-aware tools (SchemaGraph, QueryDatabase, ReadModel, RouteInspector, ReadLog, ReadFile, RunCommand, SearchCodebase, ReadRoutes), ActiveRecord session persistence, audit logging, environment permissions, and automatic service gem discovery. For internal/admin/development use. |
| **[ask-rails-harness-mcp](https://github.com/ask-rb/ask-rails-harness-mcp)** | Exposes the 9 ask-rails-harness tools over the Model Context Protocol. Run `ask-rails-harness-mcp` from your app root and Claude Code, Cursor, or any MCP client can inspect your schema, query your database, and explore your code through the same guarded tools the chat UI uses. |

## MCP

| Gem | Purpose |
|---|---|
| **[ask-mcp](https://github.com/ask-rb/ask-mcp)** | A full Model Context Protocol client and server for Ruby. Connect to MCP servers via stdio (subprocess), SSE (Server-Sent Events), or Streamable HTTP. Discover tools, resources, and prompts from any MCP server — the same protocol used by Claude Code, Codex, Cursor, and GitHub Copilot. Or run the other way: `Ask::MCP::Server.start_stdio` exposes your tools to any MCP client. Supports OAuth 2.1 authentication. |
| **[ask-web-search-mcp](https://github.com/ask-rb/ask-web-search-mcp)** | A minimal MCP server that exposes the `ask_web_search` tool over stdio. Depends on `ask-web-search` and `ask-mcp`. Query a local SearXNG instance from any MCP-compatible client (ZCode, Claude Code, Codex). Configure the SearXNG URL with `SEARXNG_URL` (defaults to `http://localhost:8888`). |

## Agent Infrastructure

| Gem | Purpose |
|---|---|
| **[ask-app-server](https://github.com/ask-rb/ask-app-server)** | A JSON-RPC/stdio app server exposing `Ask::Agent::Session` behind the standard ZCode/Codex app-server protocol (NDJSON over stdin/stdout). A drop-in replacement for `zcode app-server` — build Telegram bots, AI SDK providers, IDE extensions, and headless automation on top of it. |
| **[ask-acp](https://github.com/ask-rb/ask-acp)** | A Ruby implementation of the Agent Client Protocol (ACP): JSON-RPC 2.0 over stdio. Ships an ACP client (`Ask::ACP::Client`) that drives an agent CLI subprocess, and a server base class you subclass with `handle_*` methods. |
| **[ask-coding-providers](https://github.com/ask-rb/ask-coding-providers)** | A registry of coding-agent adapters (`:acp`, `:ask_agent`, `:claude`, `:codex`). Each adapter implements the same interface — create/resume sessions, stream messages, read workspace state — so one app can drive different coding agents. Select one with the `CODING_PROVIDER` env var. |

## Instrumentation & Observability

| Gem | Purpose |
|---|---|
| **[ask-instrumentation](https://github.com/ask-rb/ask-instrumentation)** | Emits `ActiveSupport::Notifications` events for every LLM operation — chat completions, streaming, tool calls, embeddings, and image generation (`chat.ask`, `tool.ask`, `embedding.ask`, `image.ask`, and more). Works with any provider. Subscribe to events for cost tracking, custom logging, analytics dashboards, or alerting. The foundation that all other observability gems build on. |
| **[ask-opentelemetry](https://github.com/ask-rb/ask-opentelemetry)** | Subscribes to `ask-instrumentation` events and creates OpenTelemetry spans for every LLM operation (`llm.chat`, `llm.tool`, `llm.embedding`, `llm.image`). Works with any OpenTelemetry-compatible backend — Langfuse, Datadog, Honeycomb, Jaeger, Arize Phoenix, and more. Call `Ask::OpenTelemetry.install` to start tracing; a railtie auto-installs in Rails. |
| **[ask-monitoring](https://github.com/ask-rb/ask-monitoring)** | A Rails engine that provides a monitoring dashboard at `/ask/monitoring`. Tracks cost, throughput, error rates, and response times for all LLM calls. Uses Hotwire Turbo to auto-refresh every 30 seconds. Ships Slack and email alert channels so your team gets notified when error rates spike. |

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

## Channels

| Gem | Purpose |
|---|---|
| **[ask-channel-providers](https://github.com/ask-rb/ask-channel-providers)** | Channel adapters for messaging platforms. One `Ask::ChannelProviders::Adapter` interface — start, stop, send messages, edit messages, request approvals, send cards. Ships a Telegram adapter today; Discord and Slack rendering are designed for but not yet implemented. |

## Skills

| Gem | Purpose |
|---|---|
| **[ask-skills](https://github.com/ask-rb/ask-skills)** | A skill discovery and loading system for agents. Searches project directories, user config paths, and installed gems for markdown skill files. Skills are listed in the agent's system prompt by name and description, then loaded on-demand when the agent decides it needs domain guidance. Supports enhanced frontmatter (tags, version, author, `always: true`) and sibling files (references, scripts, assets). Ships built-in skills (`skill.design`, `skill.compose`) and the `askr skills` CLI. |

## RAG

| Gem | Purpose |
|---|---|
| **[ask-rag](https://github.com/ask-rb/ask-rag)** | A RAG pipeline for the ask-rb ecosystem. Load documents from files (Text, Markdown, CSV, JSON, HTML, PDF, Directory), split them into chunks (RecursiveCharacter, Markdown), store embeddings in vector stores (InMemory, PGVector), and retrieve relevant context via similarity search. Supports metadata filtering, MMR (diversified results), and a high-level `Query.query` for one-shot retrieve → prompt → answer. Works standalone or with ask-agent through a search tool. Optional deps: `nokogiri` (HTML), `pdf-reader` (PDF), `pgvector` (PostgreSQL). |

## Evaluation

| Gem | Purpose |
|---|---|
| **[ask-eval](https://github.com/ask-rb/ask-eval)** | An LLM evaluation framework built on Minitest. Ships Minitest-native assertions — `assert_faithful` for verifying responses stay true to provided context, `assert_not_hallucinating` for detecting fabricated information, plus bias and toxicity checks. Uses LLM-as-judge for the semantic checks and deterministic assertions for basic checks. v0.2.0 adds agent session evaluation (`SessionEval`, `eval_session`) and regression recording/replay for deterministic CI. |

## UI Kit (npm)

| Package | Purpose |
|---|---|
| **[ask-ui-kit](https://github.com/ask-rb/ask-ui-kit)** | Not a Ruby gem — an npm package of 16 framework-agnostic Web Components for AI chat interfaces, built with Lit. `<ask-message>`, `<ask-thinking>`, `<ask-chat-input>`, `<ask-streaming>`, `<ask-tool-call>`, and more, usable from Rails (importmap), Svelte, React, or plain HTML. |

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
│           └── ask-app-server       ──► ask-agent, ask-state-providers
│
├── ask-web-search   ──► ask-tools
├── ask-rag          ──► ask-core
│
└── ask-mcp          ──► (no ask deps)
      ├── ask-web-search-mcp ──► ask-mcp, ask-web-search
      └── ask-acp            ──► (no ask deps)
```

## Installation

```ruby
# Single gem
gem "ask-agent"

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
