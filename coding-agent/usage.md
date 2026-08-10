---
layout: default
title: Using the Web App
parent: Coding Agent
nav_order: 1
---

# Using the Web App

The web app is a mobile-first PWA: a chat on a clean canvas, with every
tool call, todo, plan, and approval rendered inline as the turn streams.

## The chat

Type a request and send it (Shift+Enter for a new line). The agent works
through the task autonomously — you watch:

- **Text** streams in as the model thinks and writes.
- **Thinking** blocks are collapsible — the model's reasoning, shown when
  the provider reports it.
- **Tool cards** appear for every call: the tool name, its arguments, and
  the result. Command output renders in a terminal-style viewer with
  copy + expand; diff-shaped output renders in the unified diff viewer.
- **Todos** track the agent's live task list (from the `todo_write` tool).

## Approvals

By default (`ACH_APPROVAL=require`) mutating tools — `bash`, `write`,
`edit`, `apply_patch`, `code`, `repl` — queue for human approval instead
of executing:

- The turn **pauses** and an approval card shows the tool, its arguments,
  and a description.
- **Approve** runs the tool and the turn continues; **Reject** tells the
  agent and the turn continues without it.
- Multiple pending approvals offer **Approve all**.
- The **Stop** button in the header aborts the current turn.

Nothing mutates without your say-so. The approval queue exists but never
blocks when `ACH_APPROVAL=auto`; `off` removes the queue entirely.

## Plan mode

Set `ACH_PLAN_MODE=1` to make the agent research first:

1. The agent investigates with read-only tools (read, glob, grep, web
   search) and proposes a plan.
2. A plan card renders the proposal with **Approve plan** / **Reject
   plan**.
3. Approving unlocks execution — the agent works through the plan.

## Conversations

- The sidebar lists conversations (workspace-scoped), with **New
  conversation**, rename, archive, and delete.
- Conversations persist to SQLite (`ACH_DB_PATH`) and resume with full
  history on reload or from another device pointed at the same server.
- The header shows the workspace name and current git branch.

## Mobile & PWA

The app is installable: on Android via the browser menu, on iOS via
Share → Add to Home Screen. It respects safe areas, works with the
on-screen keyboard, and the shell (UI + assets) loads offline via the
service worker — the agent itself needs the server.

## Model selection

The gear icon opens Settings: workspace info (name, root, branch, adapter,
features) and the model list. The chosen model is saved locally and used
for new messages.
