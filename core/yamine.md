---
layout: default
title: Local Development
parent: Core Components
nav_order: 16
---

# Local Development

Stable, named URLs for Ruby development — `https://<app>.localhost` instead of a memorized port. `yamine` gives every app its own hostname, works across git worktrees, and stays trusted with per-host TLS.

```ruby
gem "yamine"
```

```bash
gem install yamine
cd ~/code/myapp && yamine
# -> https://myapp.localhost
```

Requires only Ruby stdlib (`openssl`, `socket`) — no extra dependencies.

## How it works

1. `yamine init` writes `config/local.yml` — the source of truth for the
   app name, its processes, and their environment (it migrates an
   existing Procfile). Booting without it fails with the fix, not a guess.
2. Boots the app — managed Rack apps on a unix socket (zero TCP ports), everything else via `PORT`.
3. Serves `https://*.localhost` on port 443 with per-host certs from a local CA, routing by `Host` header.

`.localhost` resolves to loopback natively in Chrome, Firefox, and Edge.
Safari, custom TLDs, and resolvers that read only `/etc/hosts`
(CGO-disabled Go binaries are the common case) need `yamine hosts sync`.
Doctor keeps the two apart: a name only file-only resolvers cannot see
is a warning, a name nothing resolves is a failure.

## config/local.yml

```yaml
service: myapp
proxy:
  tld: localhost              # or host: myapp.local.example.com
  subdomains: false           # opt in to answering *.myapp.localhost
processes:
  web:
    cmd: bin/rails server -p $PORT
    proxy: true
    healthcheck: { path: /up, timeout: 30 }
  worker:
    cmd: bundle exec sidekiq
    proxy: false              # background process — spawned, no route
env:
  clear:
    RAILS_ENV: development
  secret: [RAILS_MASTER_KEY]  # values come from gitignored config/local.secrets
```

Top-level `db: false` opts out of the per-worktree database. `yamine
start --wait` (the default) blocks until every healthcheck passes;
`--json` streams one machine-readable event per phase for agents.

## Pick a hostname

```
{variant}.{service}.{app}.{tld}
```

| Axis | Example | Source |
|---|---|---|
| app | `myapp` | `service:` in `config/local.yml` (`yamine init` infers it) |
| service | `api.myapp` | a non-web process name (every `proxy: true` process but `web`) |
| variant | `fix-ui.myapp` | `--variant`, `YAMINE_VARIANT`, linked worktree branch |
| tld | `myapp.preview.example.com` | `--tld` (default `localhost`) |

Linked git worktrees get a branch prefix automatically (`fix-ui.myapp.localhost`); the main checkout keeps the bare name.

```bash
yamine                              # -> https://myapp.localhost
yamine --variant demo               # -> https://demo.myapp.localhost
yamine --tld preview.example.com    # your own domain (OAuth parity)
```

Child processes receive `YAMINE_URL` (the stable URL — use it for OAuth callbacks, mailer hosts, webhook URLs), `PORT`, and `HOST`.

## Worktrees

Linked git worktrees get a branch prefix automatically
(`feature-login.myapp.localhost`); the main checkout keeps the bare name.
Each worktree also gets its own databases — the **whole set** a
multi-database app declares — so concurrent agents never share tables,
migrations, jobs, or test runs.

yamine owns the whole lifecycle:

```bash
yamine worktree add feature/login     # worktree + config + databases, ready to boot
yamine worktree list                  # every worktree: db, dirty, merged
yamine worktree remove feature/login  # stop, drop every db, remove worktree
yamine worktree clean                 # tear down everything already merged
```

`add` lands the worktree beside the repo, copies the gitignored
per-checkout config (`config/local.yml`, `config/local.secrets`,
`config/master.key`, and the development/test credential keys — never
production/staging keys), runs `bundle install`, **asks the app what
databases it has** — one `bin/rails runner` probe resolves database.yml
and credentials inside the app process, so yamine never parses config
or touches a key — and provisions every database with schema: each name
gains a collision-guarded per-worktree suffix, the test database is
created and schema-prepared (so `rails test` runs as-is), and the claim
records all names plus server coordinates. It also writes the
worktree's environment files — `.env.development` (the development
set: `DATABASE_URL` plus one `NAME_DATABASE_URL` per configuration)
and `.env.test` (the test URL under `PRIMARY_DATABASE_URL`) — mode
0600, git-excluded automatically. Only these environment-scoped names
are ever written, **never plain `.env`** (kamal, docker `--env-file`,
and dotenv-in-production all read that name), so a production boot
can never see a worktree's database URLs; existing keys in the files
are upserted, never clobbered. The
next step is just `yamine start` in it. `clean` is the done-and-merged
sweep: it never touches uncommitted work, and unmerged branches survive
everything except `remove --force` (`git branch -d` refuses what git
has not seen merged). `--dry-run` prints the plan before anything
happens.

Boot injects `DATABASE_URL` plus one `NAME_DATABASE_URL` per database
configuration (Rails' own convention), so every supervised process is
isolated. **Hand-run commands** (`rails console`, `rails test`,
`db:migrate` in your own shell) read these env files instead — which
takes two one-time things, both boring:

1. **Component-form development/test config** — `database:` keys, never
   `url:`. A `url:` key (the usual credentials-driven style) takes
   precedence over the *entire* environment: Rails skips URL-shaped
   configs when merging environment variables, so nothing injected or
   loaded can redirect them. Staging/production URLs are untouched by
   yamine either way. See the
   [yamine README](https://github.com/ask-rb/yamine#multi-database-apps)
   for the shape.
2. **A dotenv loader** — `gem "dotenv-rails", groups: [:development, :test]`
   (any dotenv loader works).

`worktree add` verifies both and prints
`.env loaded — hand-run commands are isolated too`; a warning names
exactly which requirement is missing and the fix. There is zero
yamine-specific code in `database.yml`.

```bash
yamine db describe    # what this checkout resolves to (passwords masked)
yamine db list        # every claim, every database under it
yamine db create      # re-probe + provision (after the app grows a database)
```

Teardown drops the entire set as a unit — including from an orphaned
claim whose directory is already gone, without booting the app — and
never leaves a suffixed test database behind. The main checkout never
gets these env files: its databases are its databases, untouched.

## Commands

| Command | What it does |
|---|---|
| `yamine` | Boot every process in `config/local.yml` behind the proxy |
| `yamine get <name>` | Print the URL for cross-service wiring |
| `yamine alias <name> <port>` | Static route (e.g. a Docker container) |
| `yamine list` | Show active routes and liveness |
| `yamine doctor` | Health checks (state, proxy, routes, DNS, CA) |
| `yamine open` | Open the app URL in a browser |
| `yamine log -f` | Tail the backend log |
| `yamine trust` | Add the local CA to the system trust store |
| `yamine stop` | Stop this app's backends and routes (machine-readable exit codes) |
| `yamine status` | Show the effective naming context here |
| `yamine db list\|create\|drop\|describe` | Per-worktree databases — whole sets, multi-database aware (see [Worktrees](#worktrees)) |
| `yamine worktree add\|list\|remove\|clean` | Worktree lifecycle — see [Worktrees](#worktrees) |
| `yamine hosts sync` | Write the managed block to `/etc/hosts` (Safari, custom TLDs, file-only resolvers) |
| `yamine clean` | Remove state and `/etc/hosts` entries |

## Rails integration

Rails apps need **no extra gem**. yamine injects
`RAILS_DEVELOPMENT_HOSTS=<hostname>` into each spawned process, so the
proxied `.localhost` host is allowed automatically — no `config.hosts`
patch, no initializer. Boot a Rails app the same way as anything else:

```bash
yamine init   # detects Rails, writes config/local.yml with bundle exec puma
yamine        # boots it behind https://<app>.localhost
```

Read the injected URL wherever app code needs its own address — never
hardcode `localhost:3000`:

```ruby
ENV.fetch("YAMINE_URL", "http://localhost:3000")
```

(The former `yamine-rails` gem is deprecated — its hosts patch became
the env injection, and its remaining Cable-origins helper is an optional
convenience.)

## Agent skill

The gem ships a `yamine` skill — the playbook for booting, wiring URLs,
and cleaning worktrees. With ask-skills / ask-agent it is auto-discovered
from the gem at `lib/ask/skills/yamine/SKILL.md`.

Without them, give the harness something it already knows where to look:

```bash
yamine skills install           # -> ~/.agents/skills/yamine/SKILL.md (default)
yamine skills install --local   # -> .agents/skills/yamine/SKILL.md (this repo)
yamine skills install --dir <path>  # any directory you choose
```

Most harnesses (including ZCode) discover `~/.agents/skills/` out of the box.
`yamine skills --help` shows the other forms, including uninstall.

## Next steps

- [yamine on GitHub](https://github.com/ask-rb/yamine) — routing, TLS, and worktree details
- yamine-rails — deprecated (moved to deprecated/), superseded by `RAILS_DEVELOPMENT_HOSTS` injection
