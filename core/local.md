---
layout: default
title: Local Development
parent: Core Components
nav_order: 16
---

# Local Development

Stable, named URLs for Ruby development — `https://<app>.localhost` instead of a memorized port. `ask-local` gives every app its own hostname, works across git worktrees, and stays trusted with per-host TLS.

```ruby
gem "ask-local"
```

```bash
gem install ask-local
cd ~/code/myapp && ask-local
# -> https://myapp.localhost
```

Requires only Ruby stdlib (`openssl`, `socket`) — no extra dependencies.

## How it works

1. Infers your app name from the Rails module, gemspec, `package.json`, git root, or directory.
2. Boots the app — managed Rack apps on a unix socket (zero TCP ports), everything else via `PORT`.
3. Serves `https://*.localhost` on port 443 with per-host certs from a local CA, routing by `Host` header.

`.localhost` resolves to loopback natively in Chrome, Firefox, and Edge. Safari may need `ask-local hosts sync`.

## Pick a hostname

```
{variant}.{service}.{app}.{tld}
```

| Axis | Example | Source |
|---|---|---|
| app | `myapp` | inferred, `--name`, `ask-local.json`, `ASK_LOCAL_NAME` |
| service | `api.myapp` | `--service`, `ASK_LOCAL_SERVICE` (`web` stays bare) |
| variant | `fix-ui.myapp` | `--variant`, `ASK_LOCAL_VARIANT`, linked worktree branch |
| tld | `myapp.preview.example.com` | `--tld` (default `localhost`) |

Linked git worktrees get a branch prefix automatically (`fix-ui.myapp.localhost`); the main checkout keeps the bare name.

```bash
ask-local                        # -> https://myapp.localhost
ask-local --service api          # -> https://api.myapp.localhost
ask-local --variant demo         # -> https://demo.myapp.localhost
ask-local --tld preview.example.com  # your own domain (OAuth parity)
```

Child processes receive `ASK_LOCAL_URL` (the stable URL — use it for OAuth callbacks, mailer hosts, webhook URLs), `PORT`, and `HOST`.

## Commands

| Command | What it does |
|---|---|
| `ask-local` | Infer name and boot the app |
| `ask-local run -- <cmd>` | Run an explicit command through the proxy |
| `ask-local get <name>` | Print the URL for cross-service wiring |
| `ask-local alias <name> <port>` | Static route (e.g. a Docker container) |
| `ask-local list` | Show active routes and liveness |
| `ask-local doctor` | Health checks (state, proxy, routes, DNS, CA) |
| `ask-local open` | Open the app URL in a browser |
| `ask-local log -f` | Tail the backend log |
| `ask-local trust` | Add the local CA to the system trust store |
| `ask-local clean` | Remove state and `/etc/hosts` entries |

## Rails integration

Rails apps need **no extra gem**. ask-local injects
`RAILS_DEVELOPMENT_HOSTS=<hostname>` into each spawned process, so the
proxied `.localhost` host is allowed automatically — no `config.hosts`
patch, no initializer. Boot a Rails app the same way as anything else:

```bash
ask-local init   # detects Rails, writes config/local.yml with bundle exec puma
ask-local        # boots it behind https://<app>.localhost
```

Read the injected URL wherever app code needs its own address — never
hardcode `localhost:3000`:

```ruby
ENV.fetch("ASK_LOCAL_URL", "http://localhost:3000")
```

(The former `ask-local-rails` gem is deprecated — its hosts patch became
the env injection, and its remaining Cable-origins helper is an optional
convenience.)

## Agent skill

The gem ships `local_dev` under `ask/skills/`, auto-discovered by `ask-skills`. Agents can boot via `ask-local`, wire URLs via `ask-local get`, and troubleshoot with `doctor`/`list`/`prune`.

## Next steps

- [ask-local on GitHub](https://github.com/ask-rb/ask-local) — routing, TLS, and worktree details
- ask-local-rails — deprecated (moved to ask-deprecated/), superseded by `RAILS_DEVELOPMENT_HOSTS` injection
