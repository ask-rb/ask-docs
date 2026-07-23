---
layout: default
title: Rails Integration
nav_order: 3
has_children: true
---

# Rails Integration

Give AI agents safe, controlled access to your Rails application.

`ask-rails` wires the ask-rb ecosystem into your Rails app — mounting an
admin AI agent that can inspect your database, read your code, search logs,
and run shell commands. All behind your existing authentication.

**This is for internal/admin/ops/development use.** For building customer-facing
AI features, use `ask-agent` directly (it works in any Ruby app).

| Page | What's covered |
|---|---|
| [Setup & Generators](/ask-docs/rails/setup) | Install, configure, and generate |
| [Database Tools](/ask-docs/rails/database) | SchemaGraph, RouteInspector, QueryDatabase, and more |
| [Persistence](/ask-docs/rails/persistence) | ActiveRecord-backed agent sessions |
| [Error Services](/ask-docs/rails/errors) | SolidErrors, Sentry, and Honeybadger integration |
| [Agent Integration (MCP)](/ask-docs/rails/mcp) | Connect Claude Code, Cursor, and MCP agents to your Rails app |
