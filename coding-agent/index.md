---
layout: default
title: Coding Agent
nav_order: 4
has_children: true
---

# Coding Agent

**`ask-coding-harness`** — a general-purpose coding agent in the browser,
built on the ask-rb ecosystem. Install it, point it at any project, and the
agent fires away: reading, writing, and running commands while you watch
every tool call live, approve what needs approving, and review the diffs.

No file tree, no IDE chrome — like the Codex desktop app, the harness gives
the agent full access to your project and gets out of the way.

## Quick start

```bash
gem install ask-coding-harness

cd /path/to/your/project
ask-coding-harness          # or: ach serve
```

Open http://localhost:8080. The harness runs the `ask-agent` loop
in-process with the shell toolset (`bash`, `read`, `write`, `edit`, `grep`,
`glob`, `code`, `apply_patch`) — all routed through
`ask-sandbox-providers`. Set a model via `ACH_MODEL` (or
`ASK_AGENT_MODEL`) and an API key for the provider (e.g.
`OPENCODE_API_KEY`); the ask-auth chain also reads
`~/.ask/credentials.yml`.

**No API key yet?** Try the scripted demo agent — a realistic turn with
todos, tool calls, diffs, and an approval flow, no keys needed:

```bash
ach demo
```

## What you get

- **The agent, unleashed** — `ask-agent` runs the loop in-process with the
  full shell toolset, sandboxed via `ask-sandbox-providers`.
- **Live event stream** — text deltas, thinking, tool calls, todos, and
  plan proposals stream to the browser over SSE as they happen.
- **Approvals** — mutating tools (`bash`, `write`, `edit`, ...) queue for
  your approval by default; approve, reject, or approve-all from the UI.
- **Plan mode** — opt in with `ACH_PLAN_MODE=1`: the agent researches
  read-only, proposes a plan, and only executes after you approve it.
- **Conversations** — saved to SQLite, resumable, renameable, archivable.
- **PWA** — installable on desktop and mobile; the shell works offline.
- **Extensible** — other coding agents (Codex, Claude Code, ACP-based)
  plug in via `ask-coding-providers` by setting `ACH_ADAPTER`.

| Page | What's covered |
|---|---|
| [Using the web app](/ask-docs/coding-agent/usage) | Approvals, plan mode, conversations, mobile |
| [The ach CLI](/ask-docs/coding-agent/cli) | `ach serve`, `ach demo`, `ach run`, headless dogfooding |
| [Configuration](/ask-docs/coding-agent/configuration) | Environment variables, adapters, programmatic API |
| [Architecture](/ask-docs/coding-agent/architecture) | How it fits the ask-rb ecosystem, event schema, extending |
