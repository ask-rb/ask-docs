---
layout: default
title: Rails Integration
nav_order: 3
has_children: true
---

# Rails Integration

The ask-rb ecosystem offers two gems for working with Rails:

**`ask-rails`** — Add AI capabilities to your Rails app for your users. Provides generators, file conventions, and a railtie that make `ask-agent` and `ask-graph` feel native in Rails. Define agents in `app/agents/`, workflows in `app/workflows/`, compose tools from the ecosystem, and build user-facing AI features. [Get started](/ask-docs/getting-started/rails-app){: .btn }

**`ask-rails-harness`** — An admin AI copilot mounted inside your Rails app. Gives AI agents safe, controlled access to your database, code, and logs for internal development, debugging, and ops work. Ships 9 Rails-aware tools and an admin chat UI at `/ask`. [Set up](/ask-docs/rails/setup){: .btn }

Both gems build on `ask-agent`, which provides the core agent loop. You can use one, the other, or both.

## ask-rails (user-facing AI)

| Page | What's covered |
|---|---|
| [Getting Started Guide](/ask-docs/getting-started/rails-app) | Install, define agents, add tools, stream responses |
| [Actions](/ask-docs/rails/actions) | Operations callable from any channel — web, Slack, voice |

## ask-rails-harness (admin copilot)

| Page | What's covered |
|---|---|
| [Setup & Generators](/ask-docs/rails/setup) | Install, configure, and generate |
| [Database Tools](/ask-docs/rails/database) | SchemaGraph, RouteInspector, QueryDatabase, and more |
| [Persistence](/ask-docs/rails/persistence) | ActiveRecord-backed agent sessions |
| [Error Services](/ask-docs/rails/errors) | SolidErrors, Sentry, and Honeybadger integration |
| [Agent Integration (MCP)](/ask-docs/rails/mcp) | Connect Claude Code, Cursor, and MCP agents to your Rails app |
