---
layout: default
title: Getting Started
nav_order: 1
has_children: true
---

# Getting Started

New to ask-rb? Start here. Pick the path that matches your use case.

## Which path should I take?

| **Use `ask-agent` when...** | **Use `ask-rails` when...** | **Use `ask-rails-harness` when...** |
|---|---|---|
| You want to **build AI features in any Ruby app** — not just Rails | You want to **add AI capabilities to your Rails app for your users** — chatbots, agents, natural-language features | You want to **give AI agents access to your Rails app** for internal debugging, ops, and admin work |
| You bring your own tools, UI, and persistence | You compose tools and agents from the ask-rb ecosystem | Ships with 9 Rails-aware tools (DB, filesystem, logs) and an admin chat UI at `/ask` |
| Works in any Ruby app | Requires Rails 7.1+ | Requires Rails 7.1+ |
| `gem "ask-agent"` | `gem "ask-rails"` | `gem "ask-rails-harness"` |

You can use all three together: `ask-agent` provides the core agent loop, `ask-rails` integrates it into your Rails app, and `ask-rails-harness` adds an admin copilot on top.

## Getting Started Guides

| Guide | What you'll learn |
|---|---|
| [Your First Agent](/ask-docs/getting-started/first-agent) | Install, configure, and run an ask-agent in under 5 minutes |
| [Add AI to Your Rails App](/ask-docs/getting-started/rails-app) | Set up ask-rails and build agents that use your app's data |
| [Give Agents Access to Your Rails App](/ask-docs/getting-started/rails-ai) | Connect AI agents to your Rails app for internal/admin use with ask-rails-harness |
| [Core Concepts](/ask-docs/getting-started/concepts) | The mental model behind the ecosystem |
