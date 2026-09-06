---
layout: default
title: Computer Use
parent: Core Components
nav_order: 13
---

# Computer Use

Let your agent click, type, and read desktop apps — in the background, without stealing focus. `ask-computer` drives real applications through the [Cua Driver](https://github.com/ask-rb/cua) daemon and wraps every interaction as an `Ask::Tool` your agent can call.

```ruby
gem "ask-computer"
```

## How it works

```
Agent calls a tool ──► Cua Driver (native daemon, MCP over stdio) ──► desktop app
                         │
                         └── screenshots, accessibility tree, history
```

The driver runs as its own process and talks to the app through accessibility APIs and a sandboxed VM when you ask for one. Your agent never touches the screen directly — it calls tools; the driver does the rest.

## Set up the driver

One command handles the whole flow: install the daemon, check it is running, and optionally enable encrypted Computer History.

```bash
bundle exec ask-computer setup --with-history          # stable channel + history
bundle exec ask-computer setup --channel nightly --with-history  # nightly preview
bundle exec ask-computer setup --dry-run               # preview without running
```

Or step by step:

```bash
bundle exec ask-computer install --channel nightly     # or stable (default)
bundle exec ask-computer history enable
bundle exec ask-computer status                        # driver version + health
bundle exec ask-computer history status                # raw history JSON
```

You can do the same from Ruby:

```ruby
require "ask/computer"

Ask::Computer::Installer.setup(with_history: true)
Ask::Computer::History.enable
Ask::Computer::Installer.status
```

## Use the tools

Register computer tools on any agent. Each tool maps to a Cua capability (screenshot, click, type, scroll, sandbox).

```ruby
require "ask/computer"

session = Ask::Agent::Session.new(
  model: "claude-sonnet-4-6",
  tools: Ask::Computer.tools
)

session.run("Open the spreadsheet and sum column B")
```

Or attach them selectively — hand one tool to a specific step or sub-agent rather than the whole session.

## Sandboxed VMs

Need isolation? Boot an ephemeral VM and run computer use inside it.

```ruby
Ask::Computer::Sandbox.run do |vm|
  # every click/type here happens inside the VM, not your host
end
```

The VM inherits the same tool surface; history and screenshots stay scoped to the sandbox.

## Encrypted Computer History

When enabled, the driver records every computer interaction as encrypted, bounded metadata — no screenshots or keystrokes — so you can audit what the agent did, replay a run, or debug a failure.

```ruby
Ask::Computer::History.status    # health + storage used
Ask::Computer::History.query(limit: 50, since_sequence: 100)
```

History is checked before use: `Ask::Computer::History.status` tells you whether capture is enabled, paused, or healthy, and how much encrypted storage is in use.

## Use from any MCP client

[ask-computer-mcp](https://github.com/ask-rb/ask-computer-mcp) exposes the same tools over the Model Context Protocol. Run it as an MCP stdio server so any MCP client — ZCode, Claude Code, Opencode — can drive computer use without Ruby.

```jsonc
// mcp.json
{
  "mcpServers": {
    "computer": { "command": "ask-computer-mcp" }
  }
}
```

## The skill

`ask-computer` ships `computer.use_computer` under `ask/skills/`, auto-discovered by `ask-skills`. Agents that support skills get computer-use guidance without extra setup.

## Next steps

- [Tool framework](/ask-docs/core/tools) — how `Ask::Tool` works
- [Sandbox providers](/ask-docs/core/sandbox) — isolate other tool execution too
- [ask-computer on GitHub](https://github.com/ask-rb/ask-computer) — full CLI and API reference
