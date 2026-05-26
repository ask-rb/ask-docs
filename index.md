---
layout: home
title: ask-rb
nav_exclude: true
---

# 🌀 ask-rb

**A Ruby ecosystem for building with LLMs.**

`ask-rb` is a suite of Ruby gems for building any kind of LLM-powered application — coding assistants, chatbots, batch
processors, desktop apps, RAG pipelines, and automated workflows.

```ruby
gem "ask-core"
gem "ask-openai"
gem "ask-tools"
gem "ask-agent"
```

## What you'll find here

| Section | What's covered |
|---|---|
| [ask-core](/core) | Conversation, streaming, provider interface, auth |
| [ask-agent](/agent) | Agent loop, sessions, extensions, guardrails |
| [ask-tools](/tools) | Bash, read, write, edit, glob, grep |
| [Providers](/providers) | OpenAI, Anthropic, Google, Ollama setup |
| [Design](/design) | Architecture, philosophy, design decisions |

## Design philosophy

1. **Providers own their protocols.** No shared abstraction layer. Each provider gem knows its own wire format, auth, and streaming.
2. **Conversation, tools, and streaming are one thing.** Always used together, shipped in the same gem.
3. **Schema is the only shared primitive.** JSON Schema has zero LLM dependencies and stands alone.
4. **Auth lives with the provider.** Each provider knows how to authenticate.
5. **Tools are separate from the agent loop.** Tool definitions are useful without an agent — batch scripts, REPLs, CI pipelines.
6. **Everything has a programmatic API.** Every gem can be used from Ruby code directly, not just through a CLI.
7. **Extensions are first-class.** Third-party code can hook into every lifecycle event.
8. **No required database.** In-memory is the default. ActiveRecord is an optional adapter.

## The gems

| Gem | Purpose |
|---|---|
| `ask-core` | Foundation: conversation, streaming, provider interface, auth |
| `ask-schema` | JSON Schema DSL (zero deps) |
| `ask-openai` | OpenAI + OpenAI-compatible providers |
| `ask-anthropic` | Anthropic Claude |
| `ask-google` | Google Gemini + Vertex AI |
| `ask-ollama` | Local models |
| `ask-tools` | Built-in tool implementations |
| `ask-agent` | Agent loop, sessions, extensions, telemetry |
| `ask-mcp` | MCP client and server |
| `ask-qdrant` | Qdrant vector store adapter |
| `ask-rails` | Rails integration |
| `ask-test` | VCR matchers and eval helpers |
