---
layout: default
title: Core Components
nav_order: 2
has_children: true
---

# Core Components

The building blocks of the ask-rb ecosystem. Each component is a standalone gem that you can use independently or compose into an agent.

| Component | Purpose |
|---|---|
| [LLM Providers](/ask-docs/core/providers) | OpenAI, Anthropic, Google, Ollama, Bedrock, Mistral, Cloudflare |
| [UI Kit](/ask-docs/core/ui-kit) | 16 Web Components for AI chat — Lit, Shadow DOM |
| [Tools & Execution](/ask-docs/core/tools) | Tool framework, shell tools, result types |
| [Execution Runtime](/ask-docs/core/runtime) | Shared tool-call contract, lifecycle events, cancellation, and adapters |
| [Sandbox Providers](/ask-docs/core/sandbox) | Isolated code execution — local, Docker, Daytona, Cloudflare |
| [The Agent Loop](/ask-docs/core/agent) | Session lifecycle, think-call-execute, compaction |
| [Attachments & File Inputs](/ask-docs/core/attachments) | User→agent file uploads — inline bytes or context-only manifests |
| [Workflows & Graphs](/ask-docs/core/graph) | Multi-step durable workflows with checkpointing, sub-graphs, approval, timeouts, retry |
| [Skills](/ask-docs/core/skills) | On-demand methodology for agents |
| [Schema & Structured Output](/ask-docs/core/schema) | JSON Schema DSL for tool params and structured output |
| [Credential Resolution](/ask-docs/core/auth) | Environment, file, Rails credentials, OAuth |
| [MCP Client](/ask-docs/core/mcp) | Model Context Protocol client for Ruby |
| [Web Search](/ask-docs/core/web-search) | Local SearXNG-backed web search — tool library and MCP server |
| [Web Fetch](/ask-docs/core/web-fetch) | URL → clean markdown — pluggable backends: Crawl4AI, Local, Jina, Browser (launched or attached to a running Chrome) |
| [Computer Use](/ask-docs/core/computer) | Click, type, screenshot, sandboxed VMs, encrypted Computer History via Cua Driver |
| [App Server](/ask-docs/core/app-server) | JSON-RPC/stdio app server — expose your agent to any app-server client |
| [Session Protocol](/ask-docs/core/session-protocol) | Canonical wire contract for ask sessions — events, interactions, versioning |
| [Terminal](/ask-docs/core/terminal) | Terminal thin client for the session protocol — the `ask` TUI |
| [ACP Client & Server](/ask-docs/core/acp) | Agent Client Protocol — JSON-RPC 2.0 over stdio: drive coding agents or host your own |
| [RAG Pipeline](/ask-docs/core/rag) | Document loaders, text splitters, vector stores, MMR — full RAG pipeline |
| [Decisions](/ask-docs/core/decisions) | Jev-scored decisions — route, filter, guard, compact with calibrated probabilities |
| [Token Usage](/ask-docs/core/token-usage) | Token counting, pricing, wallet engine, ledger — usage-based billing |
| [Local Development](/ask-docs/core/local) | Stable `https://<app>.localhost` URLs — zero dependencies, worktree-aware, per-host TLS |
