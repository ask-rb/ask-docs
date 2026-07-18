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
| [LLM Providers](/core/providers) | OpenAI, Anthropic, Google, Ollama, Bedrock, Mistral, Cloudflare |
| [Tools & Execution](/core/tools) | Tool framework, shell tools, result types |
| [Sandbox Providers](/core/sandbox) | Isolated code execution — local, Docker, Daytona, Cloudflare |
| [The Agent Loop](/core/agent) | Session lifecycle, think-call-execute, compaction |
| [Skills](/core/skills) | On-demand methodology for agents |
| [Schema & Structured Output](/core/schema) | JSON Schema DSL for tool params and structured output |
| [Credential Resolution](/core/auth) | Environment, file, Rails credentials, OAuth |
| [MCP Client](/core/mcp) | Model Context Protocol client for Ruby |
| [Web Search](/core/web-search) | Local SearXNG-backed web search — tool library and MCP server |
