---
layout: default
title: Configuration
parent: Coding Agent
nav_order: 3
---

# Configuration

Everything is environment-driven, so a zero-config `ach serve` works out
of the box. Programmatic use is available for embedding.

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `ACH_WORKSPACE` | current dir | project the agent operates on |
| `ACH_HOST` | `0.0.0.0` | server bind host |
| `ACH_PORT` | `8080` | server port |
| `ACH_MODEL` | `deepseek-v4-flash` | default model (alias: `ASK_AGENT_MODEL`) |
| `ACH_ADAPTER` | `ask_agent` | coding agent adapter — see below |
| `ACH_APPROVAL` | `require` | `off` \| `require` \| `auto` |
| `ACH_APPROVAL_REQUIRED` | — | comma-separated tool names gated behind approval when mode is `require` (defaults: `bash`, `write`, `edit`, `apply_patch`, `code`, `repl`) |
| `ACH_PLAN_MODE` | off | plan mode (`1`/`true`) |
| `ACH_TODOS` | on | todo list tool (`0`/`false` to disable) |
| `ACH_MAX_TURNS` | `25` | max turns per run (alias: `ASK_AGENT_MAX_TURNS`) |
| `ACH_TURN_TIMEOUT` | `600` | seconds a turn may wait for approvals before aborting |
| `ACH_DB_PATH` | `./data/ask-coding-harness.db` | conversation database |
| `ACH_SYSTEM_PROMPT` | — | extra system prompt lines (append section) |
| `system_prompt` (config) | — | custom base prompt replacing the default |
| `system_prompt_guidelines` (config) | — | extra guideline bullets |
| `ACH_MODELS` | — | comma-separated model list offered in Settings |
| `ASK_AGENT_LLM_PROVIDER` | `opencode_go` | provider slug for the `ask_agent` adapter |

## Adapters

The harness drives the ask-agent runtime by default. Other coding agents
plug in through [ask-coding-providers](/ask-docs/core/acp):

```bash
ACH_ADAPTER=acp        # any ACP-compatible agent (opencode, codex acp, claude acp)
ACH_ADAPTER=codex      # Codex app-server
ACH_ADAPTER=claude     # Claude Code CLI
ACH_ADAPTER=demo       # scripted agent (ach demo)
```

External adapters receive the approval mode and degrade gracefully when
they lack approval controls (the controls become no-ops and the turn
never blocks).

## Workspaces

The harness is universal: conversations carry their workspace directory,
and the server exposes a workspace registry.

| Endpoint | Purpose |
|---|---|
| `GET /api/workspaces` | list known workspaces (name, root, branch, conversation count) |
| `POST /api/workspaces` | open/register a workspace by path |
| `GET /api/workspaces/:path/info` | info for one workspace |
| `POST /api/chat` | accepts a `workspace` param; the conversation is created and scoped to it |

Turns execute inside their workspace directory (serialized via a turn
mutex, since the shell tools default to the process working directory),
and each session gets its workspace's system prompt.

## Programmatic API

```ruby
require "ask-coding-harness"

Ask::CodingHarness.configure do |c|
  c.workspace = "/path/to/project"
  c.model = "claude-sonnet-4"
  c.approval = :require
  c.plan_mode = true
  c.system_prompt = "You are a Rails expert."        # custom base prompt
  c.system_prompt_append = "Prefer the ask-rb conventions."
  c.system_prompt_guidelines = ["Always run tests"]
end

# Blocking web server
Ask::CodingHarness.run_server(host: "127.0.0.1", port: 8080)
```

Headless runs:

```ruby
result = Ask::CodingHarness.run("Run the test suite and fix failures")
result.success?      # => true/false
result.response      # => the final text
result.events        # => every harness event (type + data)
```

## The model catalog

Model ids resolve through `ask-llm-providers`' 402-model catalog. Provider
credentials resolve through the ask-auth chain: environment variables,
`~/.ask/credentials.yml`, Rails credentials, or OAuth — in that order.
