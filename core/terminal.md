---
layout: default
title: Terminal
parent: Core Components
nav_order: 15
---

# Terminal

The terminal client for the ask ecosystem. `ask-terminal` is a thin TUI that speaks only [`ask-session-protocol`](/ask-docs/core/session-protocol) — no runtime, no sessions, no tools of its own. The host (`ask-app-server`) owns all of that; the terminal just renders events and sends requests.

```ruby
gem "ask-terminal"
```

```bash
gem install ask-terminal   # provides the `ask` command (`ask-terminal` is an alias)
```

## One host, many clients

The same wire contract powers every client: terminal, web console, bots, IDE extensions. They can attach to the same live sessions, each receiving every event exactly once via its own delivery cursor.

## Start it

Two ways to reach the host:

```bash
# Spawn a host over stdio — it also exposes a unix socket for multi-client attach
ask
#   host socket: ~/.ask-app-server/sockets/4f3a9c2b1d0e8f7a.sock

# Attach to an already-running host over its unix socket
ask --socket ~/.ask-app-server/sockets/4f3a9c2b1d0e8f7a.sock
```

Then type a task:

```
ask> fix the failing test in spec/models
› bash grep -rn "failing" spec/
  └ bash (120ms)
── turn completed ──
```

Any client can resolve an approval or a plan proposal by id — the terminal, the web console, or a bot all do it the same way.

## Next steps

- [Session Protocol](/ask-docs/core/session-protocol) — the contract the terminal speaks
- [App Server](/ask-docs/core/app-server) — the host that runs your agent
- [ask-terminal on GitHub](https://github.com/ask-rb/ask-terminal) — CLI flags and key bindings
