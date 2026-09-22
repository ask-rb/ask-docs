---
layout: default
title: Service Contexts
nav_order: 6
has_children: true
---

# Service Contexts

Pre-built integrations for the services your agents need to interact with. Each service gem provides an authenticated client, system-prompt metadata, and structured error guidance.

> **Deprecated:** `ask-github`, `ask-slack`, `ask-notion`, `ask-linear`, `ask-sentry`, and `ask-honeybadger` are deprecated and unsupported. Prefer each company's official MCP server for those services; their guides below are legacy reference only.

| Service | Gem | Purpose |
|---|---|---|
| [GitHub](/ask-docs/services/github) | ask-github (deprecated) | Issues, PRs, repos, search |
| [Slack](/ask-docs/services/slack) | ask-slack (deprecated) | Messaging, channels, files |
| [Notion](/ask-docs/services/notion) | ask-notion (deprecated) | Pages, databases, search |
| [Linear](/ask-docs/services/linear) | ask-linear (deprecated) | Issue tracking, project management |
| [Sentry](/ask-docs/services/sentry) | ask-sentry (deprecated) | Error tracking |
| [Honeybadger](/ask-docs/services/honeybadger) | ask-honeybadger (deprecated) | Error tracking |
| [SolidErrors](/ask-docs/services/solid_errors) | ask-solid_errors | Database-backed error tracking |
| [Anychat](/ask-docs/services/anychat) | ask-anychat | Agent management API client |
| [Anychat MCP](/ask-docs/services/anychat_mcp) | ask-anychat-mcp | MCP server for Anychat agents |
| [Building a Service Gem](/ask-docs/services/custom) | — | Create your own service context |
