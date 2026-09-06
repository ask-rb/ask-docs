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

In a Rails app, use [ask-local-rails](https://github.com/ask-rb/ask-local-rails) so hosts and cable origins are wired for you.

```ruby
gem "ask-local-rails"
```

```bash
rails generate ask_local:install
```

The generator creates an initializer, allows `.localhost` hosts and Cable origins in `development.rb`, rewrites hardcoded `-p 3000` to `-p $PORT` in `Procfile.dev`, and creates an empty `ask-local.json`.

Helpers pick the right URL wherever you need one:

```ruby
Ask::Local::Rails.url     # => "https://fix-ui.myapp.localhost" (or fallback)
Ask::Local::Rails.host    # => "fix-ui.myapp.localhost"
Ask::Local::Rails.proxied? # => true when booted through ask-local
```

Use `url` for mailer hosts, OmniAuth callbacks, and webhook targets — never hardcode `localhost:3000`.

## Agent skill

The gem ships `local_dev` under `ask/skills/`, auto-discovered by `ask-skills`. Agents can boot via `ask-local`, wire URLs via `ask-local get`, and troubleshoot with `doctor`/`list`/`prune`.

## Next steps

- [ask-local on GitHub](https://github.com/ask-rb/ask-local) — routing, TLS, and worktree details
- [ask-local-rails on GitHub](https://github.com/ask-rb/ask-local-rails) — Rails helpers and generator
