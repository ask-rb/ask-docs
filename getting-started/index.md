---
layout: default
title: Getting Started
nav_order: 1
has_children: true
---

# Getting Started

New to ask-rb? Start here. Pick the path that matches your use case.

## Which path should I take?

|---|---|
| **Use ask-agent when...** | **Use ask-rails when...** |
| You want to **add AI features to your app for your users** — chatbots, automated workflows, coding assistants | You want to **give AI agents access to your Rails app** — internal admin tools, ops dashboards, dev assistants |
| You bring your own tools, your own UI, your own persistence | Ships with Rails-aware tools (DB, filesystem, logs) and an admin chat UI at `/ask` |
| Works in any Ruby app (not just Rails) | Requires Rails 7.1+ |
| Use `gem "ask-agent"` | Use `gem "ask-rails"` |

You can use both together: ask-agent provides the core agent loop, and ask-rails wires it into your Rails app with tooling and a UI.

## Getting Started Guides

| Guide | What you'll learn |
|---|---|
| [Your First Agent](/ask-docs/getting-started/first-agent) | Install, configure, and run an ask-agent in under 5 minutes |
| [Give Agents Access to Your Rails App](/ask-docs/getting-started/rails-ai) | Connect AI agents to your Rails app for internal/admin use with ask-rails |
| [Core Concepts](/ask-docs/getting-started/concepts) | The mental model behind the ecosystem |
