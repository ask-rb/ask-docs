---
layout: default
title: The ach CLI
parent: Coding Agent
nav_order: 2
---

# The `ach` CLI

`ach` is the utility CLI that ships with the harness. `ach serve` starts
the web server; `ach run` drives the same agent loop headlessly — the
dogfooding path.

## Commands

```bash
ach serve                        # web server (default command)
ach demo                         # scripted agent — no API key needed
ach run "refactor the auth flow" # headless run, prints a transcript
ach sessions                     # list saved conversations
ach version
ach help
```

### serve

```bash
ach serve
ach serve -p 3000 -H 127.0.0.1
ach serve --workspace /path/to/project --model claude-sonnet-4
ach serve --approval auto --plan-mode
```

| Flag | Purpose |
|---|---|
| `-H`, `--host` | Bind host (default `0.0.0.0`) |
| `-p`, `--port` | Port (default `8080`) |
| `-w`, `--workspace` | Project directory the agent operates on |
| `--model` | Default model |
| `--approval` | `off` \| `require` \| `auto` |
| `--plan-mode` | Enable plan mode |
| `--no-todos` | Disable the todo list |

### demo

```bash
ach demo
```

Serves the web UI against a scripted agent: a realistic turn with todos,
tool calls, a diff, and a tool call that queues for your approval. Great
for trying the product before wiring API keys.

### run — headless runs

```bash
ach run "run the test suite and fix failures"
ach run -q "just tell me the answer"        # no transcript
ach run --model claude-sonnet-4 "explain this repo"
ach run --adapter demo "show me"            # scripted agent
```

`ach run` uses the same AgentRunner as the server: the agent works through
the task with tools, and the transcript streams to your terminal (text,
thinking, tool calls, results, approvals). Headless runs default to
`--approval off` so nothing blocks on human review. The exit code is `0`
on success and `1` when the turn fails.

**Dogfooding.** ask-coding-harness builds itself with `ach run` — the
test suite includes files written by the harness running against its own
workspace. It's the fastest way to try real agentic work:

```bash
cd ask-coding-harness
ach run "write a test for the new adapter"
```

### sessions

```bash
ach sessions
```

Lists saved conversations (id prefix, title, message count, updated at) —
the same store the web app uses.

## Environment

All `ach` commands read the environment at launch; see
[Configuration](/ask-docs/coding-agent/configuration) for the full table.
